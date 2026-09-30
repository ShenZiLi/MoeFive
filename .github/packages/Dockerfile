FROM scratch

ARG VERSION

LABEL org.opencontainers.image.source="https://github.com/ShenZiLi/MoeFive" \
      org.opencontainers.image.description="MoeFive multi-platform release bundle. Contains Windows, Android, macOS, and iOS build artifacts." \
      org.opencontainers.image.version="${VERSION}"

COPY MoeFive-Windows.exe /MoeFive-Windows.exe
COPY MoeFive-Android-debug.apk /MoeFive-Android-debug.apk
COPY MoeFive-macOS.zip /MoeFive-macOS.zip
COPY MoeFive-iOS-Xcode.zip /MoeFive-iOS-Xcode.zip
COPY README-Package.txt /README-Package.txt
