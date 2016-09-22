@import GoogleMobileAds;

#import "GADMAdapterMoPub.h"

#import "GADMAdNetworkConnectorProtocol.h"
#import "GADMEnums.h"
#import "MPAdView.h"
#import "MPInterstitialAdController.h"
#import "MPNativeAdDelegate.h"
#import "MPNativeAd.h"
#import "MPStaticNativeAdRendererSettings.h"
#import "MPStaticNativeAdRenderer.h"
#import "MPNativeAdRequest.h"
#import "MPNativeAdRequestTargeting.h"
#import "MoPubAdapterMediatedNativeAd.h"
#import "MPNativeAdConstants.h"
#import "MPImageDownloadQueue.h"
#import "MPNativeAdUtils.h"
#import "MPNativeCache.h"

/// Constant for adapter error domain.
static NSString *const kAdapterErrorDomain = @"com.mopub.mobileads.MoPubAdapter";

@interface GADMAdapterMoPub () <MPAdViewDelegate, MPInterstitialAdControllerDelegate,
                             MPNativeAdDelegate>

/// Connector from Google Mobile Ads SDK to receive ad configurations.
@property(nonatomic, weak) id<GADMAdNetworkConnector> connector;

/// Handle banner ads from Sample SDK.
@property(nonatomic, strong) MPAdView *bannerAd;

/// Handle interstitial ads from Sample SDK.
@property(nonatomic, strong) MPInterstitialAdController *interstitialAd;

/// An ad loader to use in loading native ads from Sample SDK.
@property(nonatomic, strong) MPNativeAd *nativeAd;

@property(nonatomic, strong) MoPubAdapterMediatedNativeAd *mediatedAd;

@property (nonatomic, strong) MPImageDownloadQueue *imageDownloadQueue;

@property (nonatomic, strong) NSMutableDictionary *imagesDictionary;


@end

@implementation GADMAdapterMoPub


+ (NSString *)adapterVersion {
  return @"1.0";
}

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
  // OPTIONAL: Create your own class implementating GADAdNetworkExtras and return that class type
  // here for your publishers to use. This class does not use extras.

  return Nil;
}

- (instancetype)initWithGADMAdNetworkConnector:(id<GADMAdNetworkConnector>)connector {
  self = [super init];
  if (self) {
    _connector = connector;
    _imageDownloadQueue = [[MPImageDownloadQueue alloc] init];
  }
  return self;
}

- (void)getInterstitial {
  self.interstitialAd = [[MPInterstitialAdController alloc] init];
  self.interstitialAd.delegate = self;
  self.interstitialAd.adUnitId = self.connector.publisherId;
  [self.interstitialAd loadAd];
  NSLog(@"Requesting interstitial from MoPub");
    
}

- (void)stopBeingDelegate {
    self.bannerAd.delegate = nil;
    self.interstitialAd.delegate = nil;
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)rootViewController {
    if (self.interstitialAd.ready) {
        [self.interstitialAd showFromViewController:rootViewController];
    }
}

#pragma mark MoPub Ad Interstitial delegate methods

- (void)interstitialDidLoadAd:(MPInterstitialAdController *)interstitial {
    [self.connector adapterDidReceiveInterstitial:self];
}

- (void)interstitialDidFailToLoadAd:(MPInterstitialAdController *)interstitial {
    NSError *adapterError = [NSError errorWithDomain:kAdapterErrorDomain code:kGADErrorMediationNoFill userInfo:nil];
    [self.connector adapter:self didFailAd:adapterError];
}

- (void)interstitialWillAppear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterWillPresentInterstitial:self];
}

- (void)interstitialWillDisappear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterWillDismissInterstitial:self];
}

- (void)interstitialDidDisappear:(MPInterstitialAdController *)interstitial {
    [self.connector adapterDidDismissInterstitial:self];
}


//Loading Banner Ads

- (void)getBannerWithSize:(GADAdSize)adSize {

  self.bannerAd = [[MPAdView alloc] initWithAdUnitId:[self.connector credentials][@"ad_unit"] size: CGSizeMake(adSize.size.width, adSize.size.height) ] ;

  self.bannerAd.delegate = self;
  self.bannerAd.adUnitId = self.connector.publisherId;

  [self.bannerAd loadAd];
  NSLog(@"Requesting banner from Sample Ad Network");
}


- (BOOL)isBannerAnimationOK:(GADMBannerAnimationType)animType {
    return YES;
}

// Loading Native Ads

- (void)getNativeAdWithAdTypes:(NSArray *)adTypes options:(NSArray *)options {
  
  MPStaticNativeAdRendererSettings *settings = [[MPStaticNativeAdRendererSettings alloc] init];
  
  MPNativeAdRendererConfiguration *config = [MPStaticNativeAdRenderer rendererConfigurationWithRendererSettings:settings];
  NSString *moPubPublisherId = [self.connector credentials][@"ad_unit"];
  MPNativeAdRequest *adRequest = [MPNativeAdRequest requestWithAdUnitIdentifier: moPubPublisherId rendererConfigurations:@[config]];
                                                
  MPNativeAdRequestTargeting *targeting = [MPNativeAdRequestTargeting targeting];
    CLLocation *currentlocation = [[CLLocation alloc] initWithLatitude:self.connector.userLatitude longitude:self.connector.userLongitude];
    targeting.location = currentlocation;
    
  [adRequest startWithCompletionHandler:^(MPNativeAdRequest *request, MPNativeAd *response, NSError *error) {
      if (error) {
          [self.connector adapter:self didFailAd:error];
      }
      else {
          self.nativeAd = response;
          self.nativeAd.delegate = self;
      
          //---- update to include the check for GADNativeAdImageAdLoaderOptions --- rupa
          if(options!=nil && [options isKindOfClass:[GADNativeAdImageAdLoaderOptions class]]){
    
              for (GADNativeAdImageAdLoaderOptions *imageOptions in options) {
                  
                // Verify image options if image urls are requested
                if(imageOptions.disableImageLoading)
                  {
                      _mediatedAd = [[MoPubAdapterMediatedNativeAd alloc] initWithMoPubNativeAd:self.nativeAd mappedImages:nil];
                      [self.connector adapter:self didReceiveMediatedNativeAd:_mediatedAd];
                      //--return is added-- rupa
                      return;
                  }
              }
          }
        
          [self loadNativeAdImages];

      }

  }];
    
  
  NSLog(@"Requesting native ad from Sample Ad Network");
}

//Helper classes for downloading images

- (void)loadNativeAdImages {
    
    NSMutableArray *imageURLs = [NSMutableArray array];
    for (NSString *key in [self.nativeAd.properties allKeys]) {
        if ([[key lowercaseString] hasSuffix:@"image"] && [[self.nativeAd.properties objectForKey:key] isKindOfClass:[NSString class]]) {
            if ([self.nativeAd.properties objectForKey:key]) {
                NSURL *URL = [NSURL URLWithString:self.nativeAd.properties[key]];
                [imageURLs addObject:URL];
            }
            else
            {
                NSError *adapterError = [NSError errorWithDomain:kAdapterErrorDomain code:kGADErrorReceivedInvalidResponse userInfo:nil];
                [self.connector adapter:self didFailAd:adapterError];
                //--return is added-- rupa
                return;
            }
        }
    }
    
    //--- In case of invalid response error, no need to call precacheImagesWithURL. --- @hayub
    // This is not called in case of else. Its only called if imageURLs is successfully added - @rupa
    
    [self precacheImagesWithURL:imageURLs];
    
    
}

- (NSString *) returnImageKey: (NSString *) imageURL
{
    for (NSString *key in [self.nativeAd.properties allKeys]) {
        if ([[key lowercaseString] hasSuffix:@"image"] && [[self.nativeAd.properties objectForKey:key] isKindOfClass:[NSString class]]) {
           
            if([[self.nativeAd.properties objectForKey:key] isEqualToString:imageURL]) {
                return key;
            }
           
        }
    }
    
    return nil;
}

- (void)precacheImagesWithURL:(NSArray *)imageURLs
{
    _imagesDictionary = [[NSMutableDictionary alloc] init];
    
    for (NSURL *imageURL in imageURLs) {
        NSData *cachedImageData = [[MPNativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString];
    
        UIImage *image = [UIImage imageWithData:cachedImageData];
    
        if (image) {
            // By default, the image data isn't decompressed until set on a UIImageView, on the main thread. This
            // can result in poor scrolling performance. To fix this, we force decompression in the background before
            // assignment to a UIImageView.
            UIGraphicsBeginImageContext(CGSizeMake(1, 1));
            [image drawAtPoint:CGPointZero];
            UIGraphicsEndImageContext();
        
            GADNativeAdImage *nativeAdImage = [[GADNativeAdImage alloc] initWithImage:image];

            [_imagesDictionary setObject:nativeAdImage forKey:[self returnImageKey:imageURL.absoluteString]];

        }
       
    }
    
    if (_imagesDictionary.count < imageURLs.count) {
        
        NSLog(@"Cache miss on %@. Re-downloading...", imageURLs);
        
        __weak typeof(self) weakSelf = self;
        [self.imageDownloadQueue addDownloadImageURLs:imageURLs
                                      completionBlock:^(NSArray *errors) {
                                          
                                          __strong typeof(self) strongSelf = weakSelf;
                                          if (strongSelf) {
                                              if (errors.count == 0) {
                                                  for (NSURL *imageURL in imageURLs) {

                                                      UIImage *image = [UIImage imageWithData:[[MPNativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString]];

                                                      GADNativeAdImage *nativeAdImage = [[GADNativeAdImage alloc] initWithImage:image];

                                                      [strongSelf.imagesDictionary setObject:nativeAdImage forKey:[strongSelf returnImageKey:imageURL.absoluteString]];
                                                  }
                                                  
                                                  if ([strongSelf.imagesDictionary objectForKey:kAdIconImageKey] && [strongSelf.imagesDictionary objectForKey:kAdMainImageKey]) {
                                                      
                                                  strongSelf.mediatedAd = [[MoPubAdapterMediatedNativeAd alloc] initWithMoPubNativeAd:strongSelf.nativeAd mappedImages:strongSelf.imagesDictionary];
                                                   [strongSelf.connector adapter:strongSelf didReceiveMediatedNativeAd:strongSelf.mediatedAd];

                                                      
                                                  }

                                              } else {
                                                  NSLog(@"Failed to download images. Giving up for now.");
                                                  NSError *adapterError = [NSError errorWithDomain:kAdapterErrorDomain code:kGADErrorNetworkError userInfo:nil];
                                                  [strongSelf.connector adapter:strongSelf didFailAd:adapterError];
                                                  return;
                                              }
                                          } else {
                                              NSLog(@"MPNativeAd deallocated before loadImageForURL:intoImageView: download completion block was called");
                                              NSError *adapterError = [NSError errorWithDomain:kAdapterErrorDomain code:kGADErrorInternalError userInfo:nil];
                                              [strongSelf.connector adapter:strongSelf didFailAd:adapterError];
                                              return;
                                          }
                                      }];
    } else { //This block is called only if MPNativeCache already has the downloaded images. Else completion block is called where images are downloaded. Please let me know what you think. - rupa
        _mediatedAd = [[MoPubAdapterMediatedNativeAd alloc] initWithMoPubNativeAd:self.nativeAd mappedImages:_imagesDictionary];
        [self.connector adapter:self didReceiveMediatedNativeAd:_mediatedAd];
    }

}

#pragma mark MPNativeAdDelegate Methods
- (UIViewController *)viewControllerForPresentingModalView {
    return [self.connector viewControllerForPresentingModalView];
}


@end

