

@import GoogleMobileAds;

#import "MoPubAdapterConstants.h"
#import "MoPubAdapterMediatedNativeAd.h"
#import "MPNativeAd.h"
#import "MPNativeAdConstants.h"
#import "MPAdDestinationDisplayAgent.h"
#import "MPCoreInstanceProvider.h"


@interface MoPubAdapterMediatedNativeAd () <GADMediatedNativeAdDelegate, MPAdDestinationDisplayAgentDelegate>

@property(nonatomic, copy) NSArray *mappedImages;
@property(nonatomic, copy) GADNativeAdImage *mappedLogo;
@property(nonatomic, copy) NSDictionary *extras;
@property(nonatomic, copy) MPNativeAd *nativeAd;
@property(nonatomic, copy) NSDictionary *nativeAdProperties;
@property (nonatomic) MPAdDestinationDisplayAgent *displayDestinationAgent;
@property (nonatomic) UIViewController *baseViewController;
@property (nonatomic) GADNativeAdViewAdOptions *nativeAdViewOptions;
@property (nonatomic) UIImageView *privacyIconImageView;
@end

@implementation MoPubAdapterMediatedNativeAd

- (instancetype)initWithMoPubNativeAd:
        (nonnull MPNativeAd *)moPubNativeAd mappedImages: (NSMutableDictionary *)downloadedImages nativeAdViewOptions: (nonnull GADNativeAdViewAdOptions*) nativeAdViewOptions{
    
  if (!moPubNativeAd) {
    return nil;
  }

  self = [super init];
  if (self) {
    _nativeAd = moPubNativeAd;
    _nativeAdProperties = moPubNativeAd.properties;
    _nativeAdViewOptions = nativeAdViewOptions;
      
    CGFloat defaultImageScale = 1;
    
      if(downloadedImages!=nil){
          _mappedImages = [[NSArray alloc] initWithObjects:[downloadedImages objectForKey:kAdMainImageKey], nil];
          _mappedLogo = [downloadedImages objectForKey:kAdIconImageKey];
          
      }
      else{
          NSURL *mainImageUrl = [[NSURL alloc] initFileURLWithPath:[self.nativeAdProperties objectForKey:kAdMainImageKey]];
          _mappedImages = @[ [[GADNativeAdImage alloc] initWithURL:mainImageUrl scale:defaultImageScale] ];

          NSURL *logoImageURL = [[NSURL alloc] initFileURLWithPath:[self.nativeAdProperties objectForKey:kAdIconImageKey]];
          _mappedLogo = [[GADNativeAdImage alloc] initWithURL:logoImageURL scale:defaultImageScale];
      }
    
  }
  return self;
}

- (NSString *)headline {
  return [self.nativeAdProperties objectForKey:kAdTitleKey];
}

- (NSString *)body {
  return [self.nativeAdProperties objectForKey:kAdTextKey];
}

- (GADNativeAdImage *)icon {
    return self.mappedLogo;
}

- (NSArray *)images {
  return self.mappedImages;
}

- (NSString *)callToAction {
  return [self.nativeAdProperties objectForKey:kAdCTATextKey];
}

- (NSString *)advertiser {
    return nil;
}

- (NSDictionary *)extraAssets {
  return self.extras;
}

- (NSDecimalNumber *)starRating{
    return 0;
}

- (NSString *)store {
    return nil;
}

- (NSString *)price {
    return nil;
}

- (id<GADMediatedNativeAdDelegate>)mediatedNativeAdDelegate {
  return self;
}

- (void)privacyIconTapped
{
    self.displayDestinationAgent = [[MPCoreInstanceProvider sharedProvider] buildMPAdDestinationDisplayAgentWithDelegate:self];
    [self.displayDestinationAgent displayDestinationForURL:[NSURL URLWithString:kDAAIconTapDestinationURL]];
}


#pragma mark - GADMediatedNativeAdDelegate implementation

- (void)mediatedNativeAd:(id<GADMediatedNativeAd>)mediatedNativeAd
         didRenderInView:(UIView *)view viewController:(UIViewController *)viewController;
{

    UIImage *privacyIconImage = [UIImage imageNamed:kDAAIconImageName];
    
    self.baseViewController = viewController;
    
    [_nativeAd performSelector:@selector(willAttachToView:) withObject:view];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(privacyIconTapped)];
    self.privacyIconImageView.userInteractionEnabled = YES;
    [self.privacyIconImageView addGestureRecognizer:tapRecognizer];
    
    self.privacyIconImageView = [[UIImageView alloc] initWithImage:privacyIconImage];
    
    switch (_nativeAdViewOptions.preferredAdChoicesPosition) {
        case GADAdChoicesPositionTopLeftCorner:
            self.privacyIconImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
            break;
        case GADAdChoicesPositionBottomLeftCorner:
            self.privacyIconImageView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin;
            break;
        case GADAdChoicesPositionBottomRightCorner:
            self.privacyIconImageView.autoresizingMask =UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
            break;
        case GADAdChoicesPositionTopRightCorner:
            self.privacyIconImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
            break;
        default:
            self.privacyIconImageView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
            break;
    }
    
    [view addSubview:self.privacyIconImageView];

 
}

- (void)mediatedNativeAd:(id<GADMediatedNativeAd>)mediatedNativeAd
    didRecordClickOnAssetWithName:(NSString *)assetName
                             view:(UIView *)view
                   viewController:(UIViewController *)viewController {
  if (self.nativeAd) {
      [_nativeAd performSelector:@selector(adViewTapped)];
  }
    
}

- (void)mediatedNativeAd:(id<GADMediatedNativeAd>)mediatedNativeAd didUntrackView:(UIView *)view {
    if(self.privacyIconImageView) {
        [self.privacyIconImageView removeFromSuperview];
    }
}

#pragma mark - MPAdDestinationDisplayAgentDelegate

- (UIViewController *)viewControllerForPresentingModalView
{
    return self.baseViewController;
}

- (void)displayAgentDidDismissModal
{
    [GADMediatedNativeAdNotificationSource mediatedNativeAdDidDismissScreen:self];
}

- (void)displayAgentWillPresentModal
{
    [GADMediatedNativeAdNotificationSource mediatedNativeAdWillPresentScreen:self];
}

- (void)displayAgentWillLeaveApplication
{
    [GADMediatedNativeAdNotificationSource mediatedNativeAdWillLeaveApplication:self];
}


@end
