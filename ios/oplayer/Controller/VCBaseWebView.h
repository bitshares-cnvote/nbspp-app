//
//  VCBaseWebView.h
//  oplayer
//
//  Created by SYALON on 14-3-25.
//
//

#import "VCBase.h"
#import <WebKit/WebKit.h>

@interface VCBaseWebView : VCBase<WKNavigationDelegate>

- (id)initWithDefaultURL:(NSURL*)url;
- (void)loadRequest:(NSURL*)url;
- (void)reload;
- (BOOL)goBack;

- (void)onCanGoBackChanged:(BOOL)canGoBack;

@end
