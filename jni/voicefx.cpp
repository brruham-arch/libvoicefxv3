/**
 * voicefx.cpp - AML Voice FX Mod SA-MP Android
 * Engine: RubberBand LiveShifter (pitch shift real-time, tanpa tempo berubah)
 */

#include <stdint.h>
#include <string.h>
#include <math.h>
#include <dlfcn.h>
#include <android/log.h>
#include <stdio.h>
#include "RubberBandLiveShifter.h"

#define LOG_TAG "libvoicefx"
#define LOGFILE "/storage/emulated/0/voicefx_log.txt"

static void logf(const char* msg) {
    FILE* f = fopen(LOGFILE, "a");
    if (f) { fprintf(f, "%s\n", msg); fclose(f); }
}

typedef unsigned int DWORD;
typedef unsigned int HRECORD;
typedef unsigned int HDSP;
typedef void (*DSPPROC)(HDSP, DWORD, void*, DWORD, void*);

static float  g_pitch   = 1.0f;
static float  g_lastPitch = 1.0f;
static int    g_enabled = 0;
static DWORD  g_recFreq = 8000;

#define MAX_BUF 8192
static float g_inbuf[MAX_BUF];
static float g_outbuf[MAX_BUF];

static RubberBand::RubberBandLiveShifter* g_rb = nullptr;

static inline short clamp16(float v) {
    if (v >  32767.f) return  32767;
    if (v < -32768.f) return -32768;
    return (short)v;
}

static void initRB() {
    if (g_rb) { delete g_rb; g_rb = nullptr; }
    g_rb = new RubberBand::RubberBandLiveShifter(
        g_recFreq, 1,
        RubberBand::RubberBandLiveShifter::OptionDefault
    );
    g_rb->setPitchScale(g_pitch);
    g_lastPitch = g_pitch;
}

static void dspCallback(HDSP, DWORD, void* buf, DWORD len, void*) {
    if (!g_enabled || g_pitch == 1.0f) return;
    short* s16 = (short*)buf;
    int n = (int)(len / 2);
    if (n <= 0 || n > MAX_BUF) return;

    if (!g_rb) initRB();

    if (g_lastPitch != g_pitch) {
        g_rb->setPitchScale(g_pitch);
        g_lastPitch = g_pitch;
    }

    size_t blockSize = g_rb->getBlockSize();

    for (int i = 0; i < n; i++)
        g_inbuf[i] = s16[i] / 32768.0f;

    int processed = 0;
    while (processed + (int)blockSize <= n) {
        const float* in[1]  = { g_inbuf  + processed };
        float*       out[1] = { g_outbuf + processed };
        g_rb->process(in, out);
        processed += (int)blockSize;
    }

    for (int i = 0; i < processed; i++)
        s16[i] = clamp16(g_outbuf[i] * 32768.0f);
    if (processed < n)
        memset(s16 + processed, 0, (n - processed) * sizeof(short));
}

// ─── BASS fn pointers ────────────────────────────────────────
static HDSP    (*pBASSChannelSetDSP)(HRECORD, DSPPROC, void*, int)    = nullptr;
static int     (*pBASSChannelRemoveDSP)(HRECORD, HDSP)                = nullptr;
static HRECORD (*orig_BASSRecordStart)(DWORD,DWORD,DWORD,void*,void*) = nullptr;
static void*   (*pDobbySymbolResolver)(const char*, const char*)       = nullptr;
static int     (*pDobbyHook)(void*, void*, void**)                     = nullptr;

static HRECORD g_recHandle = 0;
static HDSP    g_dspHandle = 0;

static HRECORD hook_BASSRecordStart(DWORD freq, DWORD chans, DWORD flags, void* proc, void* user) {
    g_recFreq = freq;
    HRECORD handle = orig_BASSRecordStart(freq, chans, flags, proc, user);
    g_recHandle = handle;
    if (pBASSChannelSetDSP)
        g_dspHandle = pBASSChannelSetDSP(handle, dspCallback, nullptr, 1);
    logf("[VFX] RecordStart hooked");
    return handle;
}

// ─── Public API ──────────────────────────────────────────────
static void _vc_set_pitch(float f) {
    if (f < 0.25f) f = 0.25f;
    if (f > 4.0f)  f = 4.0f;
    g_pitch = f;
    if (g_rb) { g_rb->setPitchScale(f); g_lastPitch = f; }
}
static void  _vc_enable(void)     { g_enabled = 1; if (!g_rb) initRB(); }
static void  _vc_disable(void)    { g_enabled = 0; }
static int   _vc_is_enabled(void) { return g_enabled; }
static float _vc_get_pitch(void)  { return g_pitch; }

struct VcAPI {
    void  (*set_pitch)(float);
    void  (*enable)(void);
    void  (*disable)(void);
    int   (*is_enabled)(void);
    float (*get_pitch)(void);
};

// ─── AML Exports ─────────────────────────────────────────────
extern "C" {

VcAPI vc_api = {
    _vc_set_pitch, _vc_enable, _vc_disable, _vc_is_enabled, _vc_get_pitch
};

void* __GetModInfo() {
    static const char* info = "libvoicefx|3.0|VoiceFX RubberBand|brruham";
    return (void*)info;
}

void OnModPreLoad() {
    remove(LOGFILE);
    logf("[VFX] OnModPreLoad");
}

void OnModLoad() {
    logf("[VFX] OnModLoad");

    void* hDobby = dlopen("libdobby.so", RTLD_NOW | RTLD_GLOBAL);
    if (!hDobby) { logf("[VFX] ERROR: libdobby"); return; }

    pDobbySymbolResolver = (void*(*)(const char*,const char*))dlsym(hDobby, "DobbySymbolResolver");
    pDobbyHook           = (int(*)(void*,void*,void**))dlsym(hDobby, "DobbyHook");
    if (!pDobbySymbolResolver || !pDobbyHook) { logf("[VFX] ERROR: Dobby sym"); return; }

    void* hBASS = dlopen("libBASS.so", RTLD_NOW | RTLD_GLOBAL);
    if (!hBASS) { logf("[VFX] ERROR: libBASS"); return; }

    pBASSChannelSetDSP    = (HDSP(*)(HRECORD,DSPPROC,void*,int))dlsym(hBASS, "BASS_ChannelSetDSP");
    pBASSChannelRemoveDSP = (int(*)(HRECORD,HDSP))dlsym(hBASS, "BASS_ChannelRemoveDSP");

    void* addr = pDobbySymbolResolver("libBASS.so", "BASS_RecordStart");
    if (!addr) { logf("[VFX] ERROR: BASS_RecordStart addr"); return; }

    if (pDobbyHook(addr, (void*)hook_BASSRecordStart, (void**)&orig_BASSRecordStart) != 0) {
        logf("[VFX] ERROR: DobbyHook gagal"); return;
    }

    FILE* af = fopen("/storage/emulated/0/voicefx_addr.txt", "w");
    if (af) { fprintf(af, "%lu\n", (unsigned long)&vc_api); fclose(af); }

    logf("[VFX] OnModLoad SELESAI");
}

} // extern "C"
