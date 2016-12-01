//
//  NetworkManager.m
//  HTTPSAdapterDemo
//
//  Created by Lannister on 16/12/1.
//  Copyright © 2016年 郑超. All rights reserved.
//

#import "NetworkManager.h"
#import "AFHTTPSessionManager.h"

@interface NetworkManager()
@property(nonatomic,retain)AFHTTPSessionManager *manager;
@end

@implementation NetworkManager

+(instancetype)shareHttpManager{
    static dispatch_once_t onece = 0;
    static NetworkManager *httpManager = nil;
    dispatch_once(&onece, ^(void){
        httpManager = [[self alloc]init];
    });
    return httpManager;
}
//https访问
-(void)post:(NSString *)url withParameters:(id)parameters success:(void (^)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure {
    
    
    
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    securityPolicy.allowInvalidCertificates = YES;      //是否允许使用自签名证书
    securityPolicy.validatesDomainName = NO;           //是否需要验证域名
    self.manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:url]];
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.manager.securityPolicy = securityPolicy;
    self.manager.responseSerializer.acceptableContentTypes  = [NSSet setWithObjects:@"application/xml",@"text/html",@"text/xml",@"text/plain",@"application/json",nil];
    
    __weak typeof(self) weakSelf = self;
    
    [self.manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *_credential) {
        
        /// 获取服务器的trust object
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        // 导入自签名证书
        
#warning 注意将你的证书加入项目，并把下面名称改为自己证书的名称
        NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"" ofType:@"cer"];
        NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
        if (!caCert) {
            NSLog(@" ===== .cer file is nil =====");
            return nil;
        }
        NSArray *cerArray = @[caCert];
        weakSelf.manager.securityPolicy.pinnedCertificates = cerArray;
        
        SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
        NSCAssert(caRef != nil, @"caRef is nil");
        
        NSArray *caArray = @[(__bridge id)(caRef)];
        NSCAssert(caArray != nil, @"caArray is nil");
        // 将读取到的证书设置为serverTrust的根证书
        OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
        SecTrustSetAnchorCertificatesOnly(serverTrust,NO);
        NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
        //选择质询认证的处理方式
        NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        __autoreleasing NSURLCredential *credential = nil;
        
        //NSURLAuthenticationMethodServerTrust质询认证方式
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            //基于客户端的安全策略来决定是否信任该服务器，不信任则不响应质询。
            if ([weakSelf.manager.securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
                //创建质询证书
                credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                //确认质询方式
                if (credential) {
                    disposition = NSURLSessionAuthChallengeUseCredential;
                } else {
                    disposition = NSURLSessionAuthChallengePerformDefaultHandling;
                }
            } else {
                //取消挑战
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
        
        return disposition;
    }];
    
    [self.manager POST:url parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %zd",code);
        NSLog(@"%@",[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding]);
        NSDictionary *responseDic = [self jsonToDictionary:[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding]];
        success(task,responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %zd",code);
        failure(task,error);
    }];

}

- (NSDictionary *)jsonToDictionary:(NSString *)jsonString {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&jsonError];
    return resultDic;
}



@end
