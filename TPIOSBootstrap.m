#import <Foundation/Foundation.h>

extern void TPIOSStart(void);
extern void TPIOSWebDiagnosticsInstall(void);
extern void TPIOSGADInstallPresentationHook(void);

__attribute__((constructor))
static void TPIOSBootstrap(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Cài hook GAD trước TPIOSStart để chặn fullscreen ad
        // ngay từ lần present đầu tiên.
        TPIOSGADInstallPresentationHook();
        TPIOSWebDiagnosticsInstall();
        TPIOSStart();
    });
}
