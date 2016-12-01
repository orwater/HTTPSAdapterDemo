# HTTPSAdapterDemo


 在16年的WWDC中，Apple已表示将从2017年1月1日起，**所有新提交的App必须强制性应用HTTPS协议来进行网络请求。**默认情况下非HTTPS的网络访问是禁止的并且不能再通过简单粗暴的向Info.plist中添加``NSAllowsArbitraryLoads``设置绕过ATS(App Transport Security)的限制（否则须在应用审核时进行说明并很可能会被拒）。所以还未进行相应配置的公司需要尽快将升级为HTTPS的事项提上进程了。
本文将简述HTTPS及配置数字证书的原理并以配置实例和出现的问题进行说明，希望能对你提供帮助。(比心~)

###HTTPS：
简单来说，HTTPS就是HTTP协议上再加一层加密处理的SSL协议,即HTTP安全版。相比HTTP，HTTPS可以保证内容在传输过程中不会被第三方查看、及时发现被第三方篡改的传输内容、防止身份冒充，从而更有效的保证网络数据的安全。

HTTPS客户端与服务器交互过程：
1、 客户端第一次请求时，服务器会返回一个包含公钥的数字证书给客户端；
2、 客户端生成对称加密密钥并用其得到的公钥对其加密后返回给服务器；
3、 服务器使用自己私钥对收到的加密数据解密，得到对称加密密钥并保存；
4、 然后双方通过对称加密的数据进行传输。
###数字证书：
在HTTPS客户端与服务器第一次交互时，服务端返回给客户端的数字证书是让客户端验证这个数字证书是不是服务端的，证书所有者是不是该服务器，确保数据由正确的服务端发来，没有被第三方篡改。数字证书可以保证数字证书里的公钥确实是这个证书的所有者(Subject)的，或者证书可以用来确认对方身份。证书由公钥、证书主题(Subject)、数字签名(digital signature)等内容组成。其中数字签名就是证书的防伪标签，目前使用最广泛的SHA-RSA加密。

证书一般分为两种：
一种是向权威认证机构购买的证书，服务端使用该种证书时，因为苹果系统内置了其受信任的签名根证书，所以客户端不需额外的配置。为了证书安全，在证书发布机构公布证书时，证书的指纹算法都会加密后再和证书放到一起公布以防止他人伪造数字证书。而证书机构使用自己的私钥对其指纹算法加密，可以用内置在操作系统里的机构签名根证书来解密，以此保证证书的安全。
另一种是自己制作的证书，即自签名证书。好处是不需要花钱购买，但使用这种证书是不会受信任的，所以**需要我们在代码中将该证书配置为信任证书。这就是本文的主要目的。**
###具体实现
我们在使用自签名证书来实现HTTPS请求时，因为不像机构颁发的证书一样其签名根证书在系统中已经内置了，所以我们需要在App中内置自己服务器的签名根证书来验证数字证书。
首先将服务端生成的.cer格式的根证书添加到项目中，注意在添加证书要一定要记得勾选要添加的targets。**这里有个地方要注意**：苹果的ATS要求服务端必须支持TLS 1.2或以上版本；必须使用支持前向保密的密码；证书必须使用SHA-256或者更好的签名hash算法来签名，如果证书无效，则会导致连接失败。由于我在生成的根证书时签名hash算法低于其要求，在配置完请求时一直报*NSURLErrorServerCertificateUntrusted* = -1202错误，希望大家可以注意到这一点。

本文使用AFNetworking 3.0来配置证书校验。其中AFSecurityPolicy类中封装了证书校验的过程。
AFSecurityPolicy分三种验证模式：
1、AFSSLPinningModeNone：只验证证书是否在新人列表中
2、AFSSLPinningModeCertificate：验证证书是否在信任列表中，然后再对比服务端证书和客户端证书是否一致
3、 AFSSLPinningModePublicKey：只验证服务端与客户端证书的公钥是否一致
这里我们选第二种模式，并且对AFSecurityPolicy的``allowInvalidCertificates ``和 ``validatesDomainName``进行设置。

服务端在接收到客户端请求时会有的情况需要验证客户端证书，要求客户端提供合适的证书，再决定是否返回数据。这种情况即为质询(challenge)认证,双方进行公钥和私钥的验证。
为实现客户端验证，manager须设置需要身份验证回调的方法:
``` 
- (void)setSessionDidReceiveAuthenticationChallengeBlock:(NSURLSessionAuthChallengeDisposition (^)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential))block
```
并实现具体代码来替换AFNetworking的默认实现。其中参数``challenge``为身份验证质询，block返回对身份验证请求质询的配置。
在接受到质询后，客户端要根据服务端传来的challenge来生成所需的``NSURLSessionAuthChallengeDisposition disposition``和``NSURLCredential *credential``。disposition指定应对这个质询的方法，而credential是客户端生成的质询证书，注意只有challenge中认证方法为NSURLAuthenticationMethodServerTrust的时候，才需要生成挑战证书。最后回应服务器的质询。

详细代码发布在了github上，**使用时请注意在``ViewController``和``NetworkManager``中``#Warning``的提示**，将证书拖入项目并在``NetworkManager``中添加证书名称，在``ViewController``添加自己的URL。

文章中如有错误和疏漏，欢迎留言指教讨论。

####参考文章：
[Certificate, Key, and Trust Services Tasks for iOS](https://developer.apple.com/library/content/documentation/Security/Conceptual/CertKeyTrustProgGuide/iPhone_Tasks/iPhone_Tasks.html)

[关于 iOS 10 中 ATS 的问题](https://onevcat.com/2016/06/ios-10-ats/ )

[App Transport Security(ATS)]( http://southpeak.github.io/2015/09/14/app-transport-security-ats/)

[数字证书原理](http://www.cnblogs.com/JeffreySun/archive/2010/06/24/1627247.html)

[iOS使用自签名证书实现HTTPS请求]( http://www.jianshu.com/p/e6a26ecd84aa)