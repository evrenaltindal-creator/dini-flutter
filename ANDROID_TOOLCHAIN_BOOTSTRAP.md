# Android Toolchain Bootstrap

Bu proje için Android toolchain kullanıcı dizinine kurulmuştur. Ayarlar sistem geneline yazılmadan, development oturumlarında aşağıdaki değişkenlerle kullanılmalıdır.

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export ANDROID_HOME=/home/ubuntu/Android/Sdk
export ANDROID_SDK_ROOT=/home/ubuntu/Android/Sdk
export PATH=/home/ubuntu/flutter/bin:/home/ubuntu/flutter/bin/cache/dart-sdk/bin:/home/ubuntu/Android/Sdk/platform-tools:/home/ubuntu/Android/Sdk/cmdline-tools/latest/bin:/home/ubuntu/Android/Sdk/emulator:$PATH
```

Flutter SDK `/home/ubuntu/flutter` altında Flutter stable **3.47.1**, Dart **3.13.1** olarak bulundu. Android SDK `/home/ubuntu/Android/Sdk` altında command-line tools 19.0, platform-tools 37.0.1, emulator 37.1.11, Android platforms 35/36 ve build-tools 35.0.0/36.0.0 kuruldu. `Dini_Android_Test` adlı Google Play API 35 x86_64 AVD oluşturuldu.

`android/local.properties` içinde `flutter.sdk` ve `sdk.dir` yolları tanımlıdır. AVD başlatma, sandbox ortamında `/dev/kvm` bulunmadığı için tamamlanamadı; emulator runtime, APK install, app launch, logcat, widget ve notification smoke testleri bu nedenle NOT VERIFIED kalır.

Tam JDK 21 kurulumu, eksik `javac` capability’sini giderdi. Flutter local notifications bağımlılığının gerektirdiği core library desugaring, `android/app/build.gradle.kts` içinde etkinleştirildi ve `desugar_jdk_libs:2.1.5` eklendi. Bu, build/config düzeltmesidir; yeni uygulama özelliği eklenmemiştir.

Üretilen artifact kanıtları:

| Artifact | Path | Size | SHA-256 |
|---|---|---:|---|
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk` | 164,222,212 bytes | `ce5ffde764d73af8bca9527e1c0a67f2fcbd9c9db39a9f75fcdfeb2eacc34660` |
| Release AAB | `build/app/outputs/bundle/release/app-release.aab` | 53,478,387 bytes | `9ebcbab70b3abc8d5e67f6b2a403091641fac44ffe338b803dd2b4bd89d7053c` |

Release build debug signing config kullandığı için production release signing blocker olarak kalır. Gerçek production keystore veya secret signing material üretilmemiş ve source control’e eklenmemiştir.

## Phase 1 Final Report

ISLAMIC APP — ANDROID TOOLCHAIN BOOTSTRAP

FLUTTER CLI:
PASS

FLUTTER VERSION:
Flutter 3.47.1, Dart 3.13.1

ANDROID SDK:
PASS

ANDROID SDK PATH:
/home/ubuntu/Android/Sdk

PLATFORM TOOLS:
PASS

SDKMANAGER:
PASS

EMULATOR:
PASS — binary and system image installed; runtime launch blocked by missing /dev/kvm

AVD:
Dini_Android_Test

ADB:
PASS — no connected device/emulator

JDK:
PASS

JDK VERSION:
OpenJDK 21.0.12; javac 21.0.12

ANDROID LICENSES:
PASS

FLUTTER DOCTOR ANDROID:
PASS

DART FORMAT:
PASS

FLUTTER ANALYZE:
PASS

FLUTTER TEST:
PASS

TEST COUNT:
58

DEBUG APK:
PASS

DEBUG APK PATH:
build/app/outputs/flutter-apk/app-debug.apk

DEBUG APK SHA256:
ce5ffde764d73af8bca9527e1c0a67f2fcbd9c9db39a9f75fcdfeb2eacc34660

APP INSTALL:
NOT VERIFIED

APP LAUNCH:
NOT VERIFIED

RELEASE AAB:
PASS — artifact built; production signing remains blocked

RELEASE SIGNING:
BLOCKED

ANDROID TOOLCHAIN STATUS:
PARTIAL

REMAINING BLOCKERS:
1. `/dev/kvm` yok; `Dini_Android_Test` AVD başlatılamadı, bu nedenle install/launch/logcat ve native runtime kabulü yapılamadı.
2. Production release keystore mevcut değil; release config debug signing kullanıyor.
3. Premium `.dev` product ID’leri gerçek Google Play product ID’leriyle değiştirilip Play Console runtime/restore testi yapılmalı.

NEXT REQUIRED ACTION:
KVM destekli gerçek bir Android build/emulator ortamında AVD’yi başlatıp debug APK install/launch/logcat ve widget/notification smoke testlerini çalıştırmak.
