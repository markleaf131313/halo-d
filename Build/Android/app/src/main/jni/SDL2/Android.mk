LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := SDL2
LOCAL_SRC_FILES := $(LOCAL_PATH)/../../../../../../Lib/Android/$(TARGET_ARCH_ABI)/libSDL2.so

$(warning $(LOCAL_SRC_FILES))

include $(PREBUILT_SHARED_LIBRARY)