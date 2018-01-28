LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main


LOCAL_SRC_FILES := main.o
LOCAL_SHARED_LIBRARIES := SDL2


LOCAL_LDFLAGS := -fPIC -fuse-ld=bfd.exe -u SDL_main
LOCAL_LDLIBS := -lvulkan -llog

include $(BUILD_SHARED_LIBRARY)
