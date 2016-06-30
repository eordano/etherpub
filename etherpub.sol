contract EtherPub {

    address informationOwner = msg.sender;

    uint creationDate = now;

    uint randomRevealTime = now + 2 days;
    uint indexesToReveal;
    uint[] revealIndexes;
    bool canRedeem = false;
    bool calculatedRedeem = false;

    uint numberOfHashes;
    uint chunkValue;
    bytes32[] chunkHashes;
    bytes32[] preimages;

    mapping(uint => uint) balance;
    mapping(uint => address) payer;
    mapping(uint => uint) paymentTime;
    
    function EtherPub(bytes32[] hashes, uint value, uint numberOfReveals) {
        numberOfHashes = hashes.length;
        chunkHashes = hashes;
        chunkValue = value;
        indexesToReveal = numberOfReveals;
    }

    function randomReveal() {
        uint i;
        uint j;
        if (now < randomRevealTime) {
            throw;
        }
        if (calculatedRedeem) {
            throw;
        }
        uint random = 0;
        for (i = 0; i < numberOfHashes; i++) {
            for (j = 0; j < random.length; j++) {
                random[j] = bytes32(payer[i])[j] | random[j];
            }
        }
        random = sha3(random);
        for (i = 0; i < indexesToReveal; i++) {
            revealIndexes[i] = number % chunkHashes.length;
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
        if (payer[chunkNumber] != 0) {
            throw;
        }
        if (msg.value < chunkValue) {
            throw;
        }
        payer[chunkNumber] = msg.sender;
        balance[chunkNumber] = msg.value;
        paymentTime[chunkNumber] = now;
    }

    function withdraw(uint chunkNumber, bytes32 preimage) {
        if (msg.sender != informationOwner) {
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

    function refund(uint chunkNumber) {
        if (msg.sender != payer[chunkNumber]) {
            throw;
        }
        if (paymentTime[chunkNumber] + 10 days < now) {
            throw;
        }
        uint amount = balance[chunkNumber];
        balance[chunkNumber] = 0;

        if (!msg.sender.send(amount)) {
            throw;
        }
    }
}
