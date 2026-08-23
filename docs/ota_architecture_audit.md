# تدقيق مسار التحديث الهوائي (OTA)

## النطاق

يشمل التدقيق فحص إصدار GitHub، اختيار ملف APK، تنزيله والتحقق منه، ثم تسليمه إلى مثبّت Android. لا يتناول هذا المستند واجهة Flutter أو مفاتيح التوقيع.

## النتائج المؤكدة

| المجال | النتيجة | الأثر | المعالجة المطلوبة |
| --- | --- | --- | --- |
| هوية التطبيق | الإصدار المنشور `v1.0.19+569` يستخدم `com.solarexpert.calculator` وشهادة SHA-256 `3c717d35…bd37cc31`. | يمكن للمستخدمين الذين لديهم نفس الهوية والشهادة التحديث مباشرة. | لا تغيّر اسم الحزمة أو أسرار التوقيع. |
| GitHub API | فحص الإصدار يتم بلا مصادقة عند فتح شاشة الإدخال. حد GitHub العام هو 60 طلباً/ساعة لكل عنوان IP. | قد يظهر 403 للمستخدمين الذين يشاركون شبكة أو يفتحون التطبيق كثيراً. | تخزين مؤقت محلي، ETag، احترام رؤوس rate-limit، ورسائل هادئة للأخطاء المؤقتة. |
| تسليم APK | التطبيق كان يستخدم مجلد cache ثم يحذف الملف في `finally` فور تشغيل مثبّت Android. | مثبّت Android يعمل بشكل غير متزامن وقد يفقد الملف، فيظهر خطأ تحليل الحزمة. | تنزيل ذري إلى مجلد ملفات التطبيق والاحتفاظ بالنسخة التي فُتحت للمثبّت. |
| سلامة APK | GitHub Release يقدّم `sun-universal-release.apk` مع digest SHA-256، والملف المنشور يطابق الـdigest وحجمه ونوع محتواه صحيحان. | الخلل ليس في APK المنشور نفسه. | تحقق streaming من الحجم والـSHA-256 قبل الفتح. |

## التصميم المستهدف

تُخزَّن آخر استجابة Release وETag ووقت الفحص ووقت إعادة المحاولة محلياً. يستخدم التطبيق البيانات المخزنة أثناء نافذة التخزين المؤقت، ويرسل `If-None-Match` عند انتهاء النافذة. عند 304 يحدّث وقت الفحص فقط، وعند 403 أو 429 يقرأ `Retry-After` أو `X-RateLimit-Reset` ويتوقف عن إعادة الطلب حتى الموعد المناسب. لا تظهر رسالة مزعجة عند الفشل المؤقت لفحص تلقائي.

يُنزل APK إلى ملف جزئي في `ApplicationSupportDirectory`، ويتحقق من الحجم والـSHA-256 بأسلوب streaming، ثم يعيد تسمية الملف إلى امتداد APK بعد التحقق. يبقى الملف النهائي متاحاً بعد فتح مثبّت Android؛ ولا تُحذف إلا ملفات تحديثات أقدم في محاولة تنزيل لاحقة.

## المراجع

1. [GitHub REST API rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
2. [GitHub REST API best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api)
3. [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
4. [Android FileProvider secure file sharing](https://developer.android.com/training/secure-file-sharing/setup-sharing)
