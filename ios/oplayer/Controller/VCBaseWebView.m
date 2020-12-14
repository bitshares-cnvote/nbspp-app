//
//  VCBaseWebView.m
//
//  Created by SYALON on 14-3-25.
//
//

#import "VCBaseWebView.h"
#import <WebKit/WebKit.h>
#import "NJKWebViewProgressView.h"
#import "ThemeManager.h"

@interface VCBaseWebView ()
{
    NSURL*                  _default_url;
    
    NJKWebViewProgressView* _progressView;  //  loading progress view
    
    WKWebView*              _wkWebview;
}

@end

@implementation VCBaseWebView

- (void)dealloc
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    _default_url = nil;
    _progressView = nil;
    if (_wkWebview)
    {
        //  移除观察者，不移除会崩溃。
        [_wkWebview removeObserver:self forKeyPath:@"estimatedProgress"];
        [_wkWebview removeObserver:self forKeyPath:@"canGoBack"];
        _wkWebview.navigationDelegate = nil;
        [_wkWebview stopLoading];
        _wkWebview = nil;
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _wkWebview = nil;
        _progressView = nil;
        _default_url = nil;
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (id)initWithDefaultURL:(NSURL*)url
{
    self = [super init];
    if (self)
    {
        _default_url = [url copy];
    }
    return self;
}

- (void)loadRequest:(NSURL*)url
{
    if (!url){
        return;
    }
    if (_wkWebview)
    {
        [_wkWebview loadRequest:[NSURLRequest requestWithURL:url]];
    }
}

/**
 *  刷新
 */
- (void)reload
{
    if (_wkWebview)
    {
        [_wkWebview reload];
    }
}

/**
 *  回退（如果回退了则返回true，否则返回false。
 */
- (BOOL)goBack
{
    if (_wkWebview && [_wkWebview canGoBack])
    {
        [_wkWebview goBack];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //  加载进度条
    CGFloat progressBarHeight = 2.f;
    CGRect navigationBarBounds = self.navigationController.navigationBar.bounds;
    CGRect barFrame = CGRectMake(0, navigationBarBounds.size.height - progressBarHeight, navigationBarBounds.size.width, progressBarHeight);
    _progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    //  REMARK：进度条使用mainbutton的颜色
    _progressView.progressBarView.backgroundColor = [ThemeManager sharedThemeManager].mainButtonBackColor;
    
    //  根据系统版本创建加载对应的 webview
    //    if ([NativeAppDelegate systemVersion] >= 8)
    _wkWebview = [[WKWebView alloc] initWithFrame:[self rectWithoutNavi]];
    _wkWebview.navigationDelegate = self;
    _wkWebview.allowsBackForwardNavigationGestures = YES;
    [self.view addSubview:_wkWebview];
    //        [_wkWebview release];
    //  监听进度
    [_wkWebview addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [_wkWebview addObserver:self forKeyPath:@"canGoBack" options:NSKeyValueObservingOptionNew context:nil];
    
    //  加载默认URL
    if (_default_url){
        [self loadRequest:_default_url];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar addSubview:_progressView];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Remove progress view
    // because UINavigationBar is shared with other ViewControllers
    [_progressView removeFromSuperview];
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
//    self.navigationItem.title = webView.title;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark- watch WKWebView load progress...
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (keyPath && object == _wkWebview)
    {
        if ([keyPath isEqualToString:@"estimatedProgress"])
        {
            //  WKWebView 在这里设置进度
            [_progressView setProgress:_wkWebview.estimatedProgress animated:YES];
        }
        else if ([keyPath isEqualToString:@"canGoBack"])
        {
            [self onCanGoBackChanged:_wkWebview.canGoBack];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)onCanGoBackChanged:(BOOL)canGoBack
{
    //  什么也不处理，子类可以重载。
}

@end
