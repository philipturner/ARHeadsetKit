//
//  ThirdSceneSortTypes.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/18/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
using namespace metal;

class Permutation {
    ushort mask;
    friend class SubsectorDataHandle;
    
    Permutation(ushort mask)
    {
        this->mask = mask;
    }
    
    Permutation(ushort power, bool3 difference)
    {
        mask = power;
        
        ushort3 selectedMasks = select(ushort3(0), ushort3(4, 8, 16), difference);
        mask |= selectedMasks[0];
        
        ushort combinedRemainingMasks = selectedMasks[1] | selectedMasks[2];
        mask |= combinedRemainingMasks;
    }
    
public:
    Permutation()
    {
        
    }
    
    static ushort createPower(bool3 difference)
    {
        uchar4 mask(uchar3(difference), 0);
        return popcount(as_type<uint>(mask));
    }
    
    ushort getPower() const { return mask & 3; }
    
    bool3 getDifference() const
    {
        ushort3 out = ushort3(mask) >> ushort3(2, 3, 4);
        return bool3(out & 1);
    }
};

class SubsectorDataHandle {
    device void *bytePointer;
    
    // bytes 0 - 3: low micro sector ID
    // bytes 4 - 5: base offset
    // byte  6:     permutation
    
    // bytes 8 - 9: lowest offset
    // bytes 12 - 15: middle offsets
    // bytes 16 - 23: upper offsets
    
public:
    SubsectorDataHandle(device void *device_32_bytes_aligned_8, uint index)
    {
        bytePointer = reinterpret_cast<device uchar*>(device_32_bytes_aligned_8) + (index << 5);
    }
    
    
    
    void writeCommonMetadata(uint lowMicroSectorID, ushort offset0, ushort power, bool3 difference)
    {
        reinterpret_cast<device uint*>  (bytePointer)[0] = lowMicroSectorID;
        reinterpret_cast<device ushort*>(bytePointer)[2] = offset0;
        reinterpret_cast<device uchar*> (bytePointer)[6] = Permutation(power, difference).mask;
    }
    
    void writeLowestOffset(ushort lowestOffset)
    {
        reinterpret_cast<device ushort*>(bytePointer)[4] = lowestOffset;
    }
    
    void writeMiddleOffsets(ushort2 middleOffsets)
    {
        reinterpret_cast<device ushort2*>(bytePointer)[3] = middleOffsets;
    }
    
    void writeUpperOffsets(ushort4 upperOffsets)
    {
        reinterpret_cast<device ushort4*>(bytePointer)[2] = upperOffsets;
    }
    
    
    
    void readCommonMetadata(thread uint &lowSubsectorID, thread ushort &offset0,
                            thread Permutation &permutation) const
    {
        auto retrievedVector = *reinterpret_cast<device uint2*>(bytePointer);
        lowSubsectorID = retrievedVector[0];
        
        ushort2 upperHalf = as_type<ushort2>(retrievedVector[1]);
        offset0 = upperHalf[0];
        
        ushort permutationMask = as_type<uchar2>(upperHalf[1])[0];
        permutation = Permutation(permutationMask);
    }
    
    ushort readLowestOffset() const
    {
        return reinterpret_cast<device ushort*>(bytePointer)[4];
    }
    
    ushort2 readMiddleOffsets() const
    {
        return reinterpret_cast<device ushort2*>(bytePointer)[3];
    }
    
    ushort4 readUpperOffsets() const
    {
        return reinterpret_cast<device ushort4*>(bytePointer)[2];
    }
};
#endif
