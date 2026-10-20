ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk
TWEAK_NAME = StrokeLayoutDiagnostic
StrokeLayoutDiagnostic_FILES = Diagnostic.m
StrokeLayoutDiagnostic_CFLAGS = -fobjc-arc
StrokeLayoutDiagnostic_FRAMEWORKS = UIKit Foundation
StrokeLayoutDiagnostic_LIBRARIES = substrate
include $(THEOS_MAKE_PATH)/tweak.mk
