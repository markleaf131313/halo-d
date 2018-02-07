LOCAL_PATH := $(call my-dir)

LIB_PATH := $(LOCAL_PATH)/../../../../../../Lib/Android/$(TARGET_ARCH_ABI)

include $(CLEAR_VARS)
LOCAL_MODULE := druntime
LOCAL_SRC_FILES := $(LIB_PATH)/$(APP_OPTIM)/libdruntime-ldc.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := phobos
LOCAL_STATIC_LIBRARIES := druntime
LOCAL_SRC_FILES := $(LIB_PATH)/$(APP_OPTIM)/libphobos2-ldc.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := ogg
LOCAL_SRC_FILES := $(LIB_PATH)/libogg.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := vorbis
LOCAL_SHARED_LIBRARIES := ogg
LOCAL_SRC_FILES := $(LIB_PATH)/libvorbis.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := imgui
LOCAL_SRC_FILES := $(LIB_PATH)/libimgui.so
include $(PREBUILT_SHARED_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := openal
LOCAL_SRC_FILES := $(LIB_PATH)/libopenal.so
include $(PREBUILT_SHARED_LIBRARY)


include $(LOCAL_PATH)/SDL2/Android.mk