/**
 * EtherPub: trustlessly sell information per pieces.
 * 
 * Step 1: Publish this contract, with the hashes of the encryption key to
 * reveal the content of chunks of information, distributed off-chain.
 * 
 * Step 2: Wait 10000 blocks (~1.5 days).
 * 
 * Step 3: Call `randomReveal()`. This will generate a set of indexes that the
 * seller must reveal, so buyers know that the information being sold is
 * trustworthy.
 * 
 * Step 4: Seller calls `revealPreimages(bytes32[] preimages)` and shows the
 * preimages of the selected random indexes.
 * 
 * Step 5: Buyers may call `pay(chunkIndex)`
 * 
 * Step 6: Seller may redeem his payment by revealing preimages.
 *
 * Step 7: After all hashes have been revealed, or three months have passed, 
 * the contract can be destroyed.
 */
contract EtherPub {

    address informationOwner = msg.sender;
    uint randomRevealTime = block.number + 10000;
    uint creation = now;

    uint8 indexesToReveal;
    uint8[] revealIndexes;
    bool canRedeem = false;
    bool calculatedRedeem = false;

    uint minimumPayment;
    uint8 numberOfHashes;
    bytes32[] hashes;
    bytes32[] preimages;

    mapping(uint8 => uint) balance;
    
    function EtherPub(bytes32[] chunks, uint8 numberOfReveals,
                      uint minPayment) {
        if (chunks.length > 255) {
            throw;
        }
        minimumPayment = minPayment;
        numberOfHashes = uint8(chunks.length);
        hashes = chunks;
        if (numberOfReveals >= numberOfHashes) {
            throw;
        }
        indexesToReveal = numberOfReveals;
    }

    function randomReveal() {
        if (block.number < randomRevealTime) {
            throw;
        }
        if (calculatedRedeem) {
            throw;
        }
        bytes32 random = sha3(block.blockhash(randomRevealTime));
        random = sha3(random);
        for (uint8 i = 0; i < indexesToReveal; i++) {
            revealIndexes[i] = uint8(random[i]) % numberOfHashes;
        }
        calculatedRedeem = true;
    }

    function revealPreimages(bytes32[] prehash) {
        if (!calculatedRedeem || canRedeem) {
            throw;
        }
        if (prehash.length != revealIndexes.length) {
            throw;
        }
        for (uint8 i = 0; i < prehash.length; i++) {
            bytes32 hash = sha3(prehash[i]);
            if (hash != hashes[revealIndexes[i]]) {
                throw;
            }
        }
        canRedeem = true;
    }
    
    function pay(uint8 chunkNumber) {
        // The chunk to which we are paying must be a valid index.
        if (chunkNumber >= numberOfHashes) {
            throw;
        }
        // No point in paying if the chunk has already been revealed.
        if (preimages[chunkNumber] != 0) {
            throw;
        }
        // The contract owner may select a minimum amount to be paid per chunk.
        // This is to avoid a DoS that won't allow the self-destruction of the
        // contract if there's any balance left and a preimage has not been
        // revealed.
        if (msg.value < minimumPayment) {
            throw;
        }
        balance[chunkNumber] += msg.value;
    }

    function withdraw(uint8 chunkNumber, bytes32 preimage) {
        // Only the information owner can withdraw, and only if it reveals the
        // valid preimage for this chunk.
        if (msg.sender != informationOwner) {
            throw;
        }
        // Check that chunkNumber is a valid index.
        if (chunkNumber >= numberOfHashes) {
            throw;
        }
        
        // canRedeem is only true after succesful reveal of random chunks.
        if (!canRedeem) {
            throw;
        }

        bytes32 hash = sha3(preimage);
        if (hashes[chunkNumber] != hash) {
            throw;
        }
        // Store the preimage, so we know that this chunk has been revealed.
        preimages[chunkNumber] = preimage;

        uint amount = balance[chunkNumber];
        balance[chunkNumber] = 0;

        if (!msg.sender.send(amount)) {
            throw;
        }
    }

    function kill() {
        uint8 i;
        if (now < creation + 90 days) {
            // If less than 90 days elapsed, but all preimages have been
            // revealed, allow self destruction.
            for (i = 0; i < numberOfHashes; i++) {
                if (preimages[i] == 0) {
                    throw;
                }
            }
            selfdestruct(informationOwner);
        } else {
            // If the window of 256 blocks to read the block hash is closed
            if (!calculatedRedeem && block.number > randomRevealTime + 256) {
                selfdestruct(informationOwner);
            } else {
                // If there's any balance left, force user to reveal the
                // preimage before self-destructing.
                for (i = 0; i < numberOfHashes; i++) {
                    if (balance[i] > 0) {
                        throw;
                    }
                }
                selfdestruct(informationOwner);
            }
        }
    }
}
