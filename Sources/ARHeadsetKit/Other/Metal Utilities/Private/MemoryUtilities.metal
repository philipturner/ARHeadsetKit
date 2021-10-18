//
//  MemoryUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/15/21.
//

#include <metal_stdlib>
#include "../MemoryUtilities.h"
using namespace metal;

ushort BinarySearch::binarySearch(uint element, constant uint *list, ushort listSizeMinus1)
{
    ushort lowerBound = 0;
    ushort upperBound = listSizeMinus1;
    
    while (lowerBound != upperBound)
    {
        ushort midPoint = rhadd(lowerBound, upperBound);

        if (list[midPoint] > element)
        {
            upperBound = midPoint - 1;
        }
        else
        {
            lowerBound = midPoint;
        }
    }

    return lowerBound;
}



ushort3 DualID::pack(uint2 id)
{
    return {
        as_type<ushort4>(id)[0],
        as_type<ushort>(uchar2(as_type<uchar4>(id.x).z,
                               as_type<uchar4>(id.y).z)),
        as_type<ushort4>(id)[2]
    };
}

ushort3 DualID::pack(uint x, uint y)
{
    return {
        as_type<ushort2>(x)[0],
        as_type<ushort>(uchar2(as_type<uchar4>(x).z,
                               as_type<uchar4>(y).z)),
        as_type<ushort2>(y)[0]
    };
}

uint2 DualID::unpack(ushort3 id)
{
    ushort4 output;
    
    output[0] = id[0];
    output[2] = id[2];
    
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).x, 0));
    output[3] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).y, 0));
    
    return as_type<uint2>(output);
}

uint DualID::getX(ushort3 id)
{
    ushort2 output;
    
    output[0] = id[0];
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).x, 0));
    
    return as_type<uint>(output);
}

uint DualID::getY(ushort3 id)
{
    ushort2 output;
    
    output[0] = id[2];
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).y, 0));
    
    return as_type<uint>(output);
}

void DualID::setX(device ushort3 *id, uint x)
{
    reinterpret_cast<device ushort*>(id)[0] = as_type<ushort2>(x)[0];
    reinterpret_cast<device uchar*> (id)[2] = as_type<uchar4> (x)[2];
}

void DualID::setY(device ushort3 *id, uint y)
{
    reinterpret_cast<device ushort*>(id)[2] = as_type<ushort2>(y)[0];
    reinterpret_cast<device uchar*> (id)[3] = as_type<uchar4> (y)[2];
}



uint PackedID10::get(device void *device_32_bytes, ushort index, uint bufferOffset)
{
    auto ids = reinterpret_cast<device uchar*>(device_32_bytes);
    auto selectedIDs = ids + (bufferOffset + (index << 1) + index);
    
    uchar4 output = {
        selectedIDs[0],
        selectedIDs[1],
        selectedIDs[2],
        0
    };
    
    return as_type<uint>(output);
}

void PackedID10::set(device void *device_32_bytes, ushort index, uint id, uint bufferOffset)
{
    auto ids = reinterpret_cast<device uchar*>(device_32_bytes);
    auto selectedIDs = ids + (bufferOffset + (index << 1) + index);
    
    selectedIDs[0] = as_type<uchar4>(id)[0];
    selectedIDs[1] = as_type<uchar4>(id)[1];
    selectedIDs[2] = as_type<uchar4>(id)[2];
}



namespace InternalCorrectWrite {
    template <typename T>
    void setX(device vec<T, 2> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = id << 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setY(device vec<T, 2> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 1) + 1;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setX(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = id << 2;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setY(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setZ(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 2;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setW(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 3;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setXY(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device vec<T, 2> *>(pointer);
        uint index = id << 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setXZ(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += id << 2;
        
        targetPointer[0] = value[0];
        targetPointer[2] = value[1];
    }
    
    template <typename T>
    void setXW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += id << 2;
        
        targetPointer[0] = value[0];
        targetPointer[3] = value[1];
    }
    
    template <typename T>
    void setYZ(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value[0];
        targetPointer[1] = value[1];
    }
    
    template <typename T>
    void setYW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value[0];
        targetPointer[2] = value[1];
    }
    
    template <typename T>
    void setZW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device vec<T, 2> *>(pointer);
        uint index = (id << 1) + 1;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setXYZ(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        *reinterpret_cast<device vec<T, 2> *>(targetPointer) = value.xy;
        targetPointer[2] = value.z;
    }
    
    template <typename T>
    void setXYW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        *reinterpret_cast<device vec<T, 2> *>(targetPointer) = value.xy;
        targetPointer[3] = value.z;
    }
    
    template <typename T>
    void setXZW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        targetPointer[0] = value.x;
        reinterpret_cast<device vec<T, 2> *>(targetPointer)[1] = value.yz;
    }
    
    template <typename T>
    void setYZW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value.x;
        *reinterpret_cast<device vec<T, 2> *>(targetPointer + 1) = value.yz;
    }
}

#define makeFunc(funcName, scalar, vecSize)                                 \
void CorrectWrite::funcName(device vec<scalar, vecSize> *pointer, uint id,  \
                                       scalar value)                        \
{                                                                           \
    InternalCorrectWrite::funcName(pointer, id, value);                     \
}                                                                           \
// forced space for concatenating files
#define makeMultiFunc(funcName, scalar, vecSize, inputSize)                 \
void CorrectWrite::funcName(device vec<scalar, vecSize> *pointer, uint id,  \
                                   vec<scalar, inputSize> value)            \
{                                                                           \
    InternalCorrectWrite::funcName(pointer, id, value);                     \
}                                                                           \
// forced space for concatenating files
#define makeFuncFamily(scalar)                                              \
makeFunc(setX, scalar, 2)                                                   \
makeFunc(setY, scalar, 2)                                                   \
                                                                            \
makeFunc(setX, scalar, 4)                                                   \
makeFunc(setY, scalar, 4)                                                   \
makeFunc(setZ, scalar, 4)                                                   \
makeFunc(setW, scalar, 4)                                                   \
                                                                            \
makeMultiFunc(setXY, scalar, 4, 2)                                          \
makeMultiFunc(setXZ, scalar, 4, 2)                                          \
makeMultiFunc(setXW, scalar, 4, 2)                                          \
makeMultiFunc(setYZ, scalar, 4, 2)                                          \
makeMultiFunc(setYW, scalar, 4, 2)                                          \
makeMultiFunc(setZW, scalar, 4, 2)                                          \
                                                                            \
makeMultiFunc(setXYZ, scalar, 4, 3)                                         \
makeMultiFunc(setXYW, scalar, 4, 3)                                         \
makeMultiFunc(setXZW, scalar, 4, 3)                                         \
makeMultiFunc(setYZW, scalar, 4, 3)                                         \
// forced space for concatenating files
makeFuncFamily(bool)
makeFuncFamily(uchar)
makeFuncFamily(ushort)
makeFuncFamily(uint)
makeFuncFamily(ulong)

makeFuncFamily(char)
makeFuncFamily(short)
makeFuncFamily(int)
makeFuncFamily(long)

makeFuncFamily(half)
makeFuncFamily(float)
