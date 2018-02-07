LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

BUILD_PATH := $(LOCAL_PATH)/../../../../../../

LOCAL_MODULE := main

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../libs/SDL2/include

LOCAL_SRC_FILES := main.o
LOCAL_STATIC_LIBRARIES := phobos
LOCAL_SHARED_LIBRARIES := SDL2 imgui openal ogg vorbis

LOCAL_LDFLAGS := -fPIC -fuse-ld=bfd.exe -u SDL_main
LOCAL_LDLIBS := -landroid -lc -lm -lvulkan -llog

include $(BUILD_SHARED_LIBRARY)

OBJ_FILE := $(LOCAL_OBJS_DIR)/main.o

$(OBJ_FILE):
	python3 --version
	python3 $(BUILD_PATH)/Build.py Android --output=$(OBJ_FILE)

.PHONY: $(OBJ_FILE)