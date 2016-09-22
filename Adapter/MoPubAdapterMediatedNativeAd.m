

@import GoogleMobileAds;

#import "MoPubAdapterConstants.h"
#import "MoPubAdapterMediatedNativeAd.h"
#import "MPNativeAd.h"
#import "MPNativeAdConstants.h"

// You may notice that this class and the Custom Event's
// SampleMediatedNativeContentAd class look an awful lot alike. That's not
// by accident. They're the same class, with the same methods and properties,
// but with two different names.
//
// Mediation adapters and custom events map their native ads for the
// Google Mobile Ads SDK using extensions of the same two classes:
// GADMediatedNativeAppInstallAd and GADMediatedNativeContentAd. Because both
// the adapter and custom event in this example are mediating the same Sample
// SDK, they both need the same work done: take a native ad object from the
// Sample SDK and map it to the interface the Google Mobile Ads SDK expects.
// Thus, the same classes work for both.
//
// Because we wanted this project to have a complete example of an
// adapter and a complete example of a custom event (and we didn't want to
// share code between them), they each get their own copies of these classes,
// with slightly different names.

@interface MoPubAdapterMediatedNativeAd () <GADMediatedNativeAdDelegate>

@property(nonatomic, copy) NSArray *mappedImages;
@property(nonatomic, strong) GADNativeAdImage *mappedLogo;
@property(nonatomic, copy) NSDictionary *extras;
@property(nonatomic,strong) MPNativeAd *nativeAd;
@property(nonatomic,strong) NSDictionary *nativeAdProperties;

@end

@implementation MoPubAdapterMediatedNativeAd

- (instancetype)initWithMoPubNativeAd:
        (nonnull MPNativeAd *)moPubNativeAd mappedImages: (NSMutableDictionary *)downloadedImages {
    
  if (!moPubNativeAd) {
    return nil;
  }

  self = [super init];
  if (self) {
    _nativeAd = moPubNativeAd;
    _nativeAdProperties = moPubNativeAd.properties;

    //rupa fill the extras
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

- (NSArray *)images {
  return self.mappedImages;
}

- (GADNativeAdImage *)logo {
  return self.mappedLogo;
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

- (id<GADMediatedNativeAdDelegate>)mediatedNativeAdDelegate {
  return self;
}

#pragma mark - GADMediatedNativeAdDelegate implementation

// Because the Sample SDK handles click and impression tracking via methods on its native
// ad object, there's no need to pass it a reference to the UIView being used to display
// the native ad. So there's no need to implement mediatedNativeAd:didRenderInView here.
// If your mediated network does need a reference to the view, this method can be used to
// provide one.

- (void)mediatedNativeAd:(id<GADMediatedNativeAd>)mediatedNativeAd
         didRenderInView:(UIView *)view viewController:(UIViewController *)viewController;
{
    [_nativeAd performSelector:@selector(willAttachToView:) withObject:view];
}

- (void)mediatedNativeAd:(id<GADMediatedNativeAd>)mediatedNativeAd
    didRecordClickOnAssetWithName:(NSString *)assetName
                             view:(UIView *)view
                   viewController:(UIViewController *)viewController {
  if (self.nativeAd) {
      [_nativeAd performSelector:@selector(adViewTapped)];
  }
}


@end
