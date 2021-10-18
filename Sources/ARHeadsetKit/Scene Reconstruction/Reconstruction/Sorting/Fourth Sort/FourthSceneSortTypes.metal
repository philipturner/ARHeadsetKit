//
//  FourthSceneSortTypes.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/18/21.
//

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
    
    // bytes 0 - 3: low nano sector ID
    // bytes 4 - 5: base offset
    // byte  6:     permutation
    // byte  7:     lowest offset
    
    // bytes 8 - 9: middle offsets
    // bytes 12 - 15: upper offsets
    
public:
    SubsectorDataHandle(device void *device_16_bytes, uint index)
    {
        bytePointer = reinterpret_cast<device uchar*>(device_16_bytes) + (index << 4);
    }
    
    void writeCommonMetadata(uint lowMicroSectorID, ushort offset0, ushort power, bool3 difference)
    {
        reinterpret_cast<device uint*>  (bytePointer)[0] = lowMicroSectorID;
        reinterpret_cast<device ushort*>(bytePointer)[2] = offset0;
        reinterpret_cast<device uchar*> (bytePointer)[6] = Permutation(power, difference).mask;
    }
    
    void writeLowestOffset(ushort lowestOffset)
    {
        reinterpret_cast<device uchar*>(bytePointer)[7] = uchar(lowestOffset);
    }
    
    void writeMiddleOffsets(ushort2 middleOffsets)
    {
        reinterpret_cast<device uchar2*>(bytePointer)[4] = uchar2(middleOffsets);
    }
    
    void writeUpperOffsets(ushort4 upperOffsets)
    {
        reinterpret_cast<device uchar4*>(bytePointer)[3] = uchar4(upperOffsets);
    }
    
    
    
    void readCommonMetadata(thread uint &lowSubsectorID,     thread ushort &offset0,
                            thread Permutation &permutation, thread ushort &lowestOffset) const
    {
        auto retrievedVector = *reinterpret_cast<device uint2*>(bytePointer);
        lowSubsectorID = retrievedVector[0];
        
        ushort2 upperHalf = as_type<ushort2>(retrievedVector[1]);
        offset0 = upperHalf[0];
        
        ushort permutationMask = ushort(as_type<uchar2>(upperHalf[1])[0]);
        permutation = Permutation(permutationMask);
        
        lowestOffset = ushort(as_type<uchar2>(upperHalf[1])[1]);
    }
    
    ushort2 readMiddleOffsets() const
    {
        return ushort2(reinterpret_cast<device uchar2*>(bytePointer)[4]);
    }
    
    ushort4 readUpperOffsets() const
    {
        return ushort4(reinterpret_cast<device uchar4*>(bytePointer)[3]);
    }
};
