
@import Foundation;
#import "MPNativeAd.h"

@interface MoPubAdapterMediatedNativeAd : NSObject<GADMediatedNativeAppInstallAd>

- (instancetype)initWithMoPubNativeAd:(nonnull MPNativeAd *)mopubNativeAd mappedImages: (nullable NSMutableDictionary *) downloadedImages nativeAdViewOptions: (nonnull GADNativeAdViewAdOptions*) nativeAdViewOptions;

@end
