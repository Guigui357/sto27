// ================================================================
// AppDelegate.m - Interface Programática (Sem Storyboard)
// ================================================================

#import "AppDelegate.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Cria a window
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    // Cria o ViewController
    ViewController *vc = [[ViewController alloc] init];
    
    // Coloca na navigation controller (opcional, mas bom para navegação)
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBarHidden = YES; // Esconde a barra de navegação
    
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
