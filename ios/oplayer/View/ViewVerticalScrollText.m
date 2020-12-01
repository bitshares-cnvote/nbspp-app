//
//  ViewVerticalScrollText.m
//  oplayer
//
//  Created by SYALON on 13-12-31.
//
//

#import "ViewVerticalScrollText.h"
#import "ViewUtils.h"
#import "UIImage+Template.h"
#import "ThemeManager.h"
#import "NativeAppDelegate.h"
#import "OrgUtils.h"

#define fIconHeight 20

@interface ViewVerticalScrollText()
{
    UIImageView*    _icon;
    UIView*         _bottomLine;
    
    UIView*         _contaier;
    
    UILabel*        _currLabel;
    UILabel*        _nextLabel;
    NSInteger       _displayIndex;
}

@end

@implementation ViewVerticalScrollText

- (void)dealloc
{
    _icon = nil;
    [self cleanTextArrayLabel];
}

- (void)cleanTextArrayLabel
{
    if (_currLabel && _currLabel.superview) {
        [_currLabel removeFromSuperview];
    }
    _currLabel = nil;
    
    if (_nextLabel && _nextLabel.superview) {
        [_nextLabel removeFromSuperview];
    }
    _nextLabel = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        _displayIndex = 0;

        _icon = [[UIImageView alloc] initWithImage:[UIImage templateImageNamed:@"iconExplorer"]];
        [self addSubview:_icon];
        
        _bottomLine = [[UIView alloc] init];
        [self addSubview:_bottomLine];
        
        _contaier = [[UIView alloc] init];
        _contaier.clipsToBounds = YES;
        _contaier.userInteractionEnabled = NO;
        [self addSubview:_contaier];
        
        _currLabel = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:14] superview:_contaier];
        _currLabel.textAlignment = NSTextAlignmentLeft;
        _currLabel.userInteractionEnabled = NO;
        
        _nextLabel = [ViewUtils auxGenLabel:[UIFont boldSystemFontOfSize:14] superview:_contaier];
        _nextLabel.textAlignment = NSTextAlignmentLeft;
        _nextLabel.userInteractionEnabled = NO;
        
        [self doScrollCore:@"start"];
        
        self.userInteractionEnabled = YES;
        UITapGestureRecognizer* pLabelClickedGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onLabelClicked)];
        [self addGestureRecognizer:pLabelClickedGesture];
    }
    return self;
}

- (void)onLabelClicked
{
    if (!_textArray || [_textArray count] <= 0) {
        return;
    }
    if (_displayIndex >= [_textArray count]) {
        return;
    }
    id item = [_textArray objectAtIndex:_displayIndex];
    id url = [item objectForKey:@"url"];
    if (!url || [url isEqualToString:@""]) {
        return;
    }
    [OrgUtils safariOpenURL:url];
}

- (void)setTextArray:(NSArray*)textArray
{
    if (!textArray || [textArray count] <= 0) {
        return;
    }
    if (_textArray == textArray) {
        return;
    }
    if ((!_textArray || [_textArray count] <= 0) && [textArray count] > 0) {
        _currLabel.text = [textArray[0] objectForKey:@"title"] ?: @"";
        if ([textArray count] > 1)
            _nextLabel.text = [textArray[1] objectForKey:@"title"] ?: @"";
        else
            _nextLabel.text = @"";
    }
    _textArray = [textArray copy];
    _displayIndex = 0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize size = self.bounds.size;
    CGFloat fOffsetX = 12;
    CGFloat fHeight = size.height;
    
    _icon.frame = CGRectMake(fOffsetX, (fHeight - fIconHeight) / 2, fIconHeight, fIconHeight);
    _icon.tintColor = [ThemeManager sharedThemeManager].textColorMain;
    
    _bottomLine.frame = CGRectMake(0, size.height - 0.5f, size.width, 0.5f);
    _bottomLine.backgroundColor = [ThemeManager sharedThemeManager].bottomLineColor;
    
    _contaier.frame = CGRectMake(fOffsetX + fIconHeight + 4, 0, size.width - fOffsetX * 2 - fIconHeight - 4, fHeight);
    
    CGSize sizeContaier = _contaier.bounds.size;
    _currLabel.frame = CGRectMake(0, 0, sizeContaier.width, sizeContaier.height);
    _nextLabel.frame = CGRectMake(0, sizeContaier.height, sizeContaier.width, sizeContaier.height);
}

#pragma mark- scroll

- (NSInteger)nextIndex:(NSInteger)index
{
    return (index + 1) % [_textArray count];
}

- (void)doScrollCore:(id)args
{
    if (![self isCurrentViewControllerVisible]) {
        [self performSelector:@selector(doScrollCore:) withObject:nil afterDelay:3.0f];
        return;
    }
    
    if (!_textArray || [_textArray count] <= 0) {
        [self performSelector:@selector(doScrollCore:) withObject:nil afterDelay:0.3f];
        return;
    }
    
    if ([_textArray count] == 1) {
        _currLabel.text = [[_textArray firstObject] objectForKey:@"title"] ?: @"";
        _nextLabel.text = @"";
        [self performSelector:@selector(doScrollCore:) withObject:nil afterDelay:3.0f];
        return;
    }
    
    NSInteger saveIndex = _displayIndex;
    
    _currLabel.text  = [_textArray[saveIndex] objectForKey:@"title"] ?: @"";
    _nextLabel.text  = [_textArray[[self nextIndex:saveIndex]] objectForKey:@"title"] ?: @"";
    
    CGSize size = _contaier.bounds.size;
    _currLabel.frame = CGRectMake(0, 0, size.width, size.height);
    _nextLabel.frame = CGRectMake(0, size.height, size.width, size.height);

    [UIView animateWithDuration:0.3f delay:5.0f options:UIViewAnimationOptionLayoutSubviews animations:^{
        _currLabel.frame = CGRectMake(0, -size.height, size.width, size.height);
        _nextLabel.frame = CGRectMake(0, 0, size.width, size.height);
    } completion:^(BOOL finished) {
        _displayIndex = [self nextIndex:saveIndex];

        UILabel* temp = _currLabel;
        _currLabel = _nextLabel;
        _nextLabel = temp;
        
        _currLabel.userInteractionEnabled = YES;
        _nextLabel.userInteractionEnabled = YES;

        [self performSelector:@selector(doScrollCore:) withObject:nil];
    }];
}

#pragma mark- aux method
-(BOOL)isCurrentViewControllerVisible
{
    UIViewController* vc = [self currentViewController];
    return vc && vc.isViewLoaded && vc.view.window && [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}

- (UIViewController *)currentViewController {
    for (UIView * next = [self superview]; next; next = next.superview) {
        UIResponder * nextResponder = [next nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)nextResponder;
        }
    }
    return nil;
}

@end
