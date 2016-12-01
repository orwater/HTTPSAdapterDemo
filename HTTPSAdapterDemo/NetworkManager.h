//
//  NetworkManager.h
//  HTTPSAdapterDemo
//
//  Created by Lannister on 16/12/1.
//  Copyright © 2016年 郑超. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkManager : NSObject
+(instancetype)shareHttpManager;

-(void)post:(NSString *)url withParameters:(id)parameters success:(void (^)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;
@end
