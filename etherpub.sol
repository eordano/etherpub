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
 */
contract EtherPub {

    address informationOwner = msg.sender;

    uint creationDate = now;
    uint randomRevealTime = block.number + 10000;

    uint indexesToReveal;
    uint[] revealIndexes;
    bool canRedeem = false;
    bool calculatedRedeem = false;

    uint numberOfHashes;
    bytes32[] chunkHashes;
    bytes32[] preimages;

    mapping(uint => uint) balance;
    
    function EtherPub(bytes32[] hashes, uint numberOfReveals) {
        numberOfHashes = hashes.length;
        chunkHashes = hashes;
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
        for (uint i = 0; i < indexesToReveal; i++) {
            revealIndexes[i] = uint8(random[i]) % chunkHashes.length;
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
        for (uint i = 0; i < prehash.length; i++) {
            bytes32 hash = sha3(prehash[i]);
            if (hash != chunkHashes[revealIndexes[i]]) {
                throw;
            }
        }
        canRedeem = true;
    }
    
    function pay(uint chunkNumber) {
        if (chunkNumber > chunkHashes.length) {
            throw;
        }
        balance[chunkNumber] += msg.value;
    }

    function withdraw(uint chunkNumber, bytes32 preimage) {
        if (msg.sender != informationOwner) {
            throw;
        }
        if (chunkNumber > chunkHashes.length) {
            throw;
        }
        if (balance[chunkNumber] < 1) {
            throw;
        }
        if (!canRedeem) {
            throw;
        }

        bytes32 hash = sha3(preimage);
        if (chunkHashes[chunkNumber] != hash) {
            throw;
        }
        preimages[chunkNumber] = preimage;

        uint amount = balance[chunkNumber];
        balance[chunkNumber] = 0;

        if (!msg.sender.send(amount)) {
            throw;
        }
    }
}
