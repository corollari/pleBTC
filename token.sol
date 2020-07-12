pragma solidity ^0.6.6;

// Forked from (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

contract token is Owned {

    string public symbol;
    string public name;
    uint8 public decimals;
    uint public _totalSupply;
    uint public collateralRate;
    uint public collateral;
    mapping(address => bytes) public owners;
    
    struct Mint{
        uint amount;
        bytes btcPublicKey;
    }
    mapping(address=>Mint) public mints;
    uint btcEthPrice;
    struct PendingTransfer{
        uint utxoId;
        address from;
        address to;
        bytes encryptedPrivateKey;
    }
    mapping(uint=>PendingTransfer) public transfers;
    address oracle;

    struct Utxo {
        uint amount;
        address owner;
    }
    mapping(uint => Utxo) utxos;


    constructor() public {
        symbol = "pleBTC";
        name = "pleBTC";
        decimals = 18;
        collateralRate = 30; // 30%
        _totalSupply = 0;
        collateral = 0;
        oracle = msg.sender; // This needs to be changed to make the oracle a different entity but for now it'll work
        //balances[owner] = _totalSupply;
        //Transfer(address(0), owner, _totalSupply);
    }
    
    // There's no need to set up punishments if the collateral becomes too low because, if that happens, the users will already leave by themselves
    function setPrice(uint newPrice) public{
        require(msg.sender == oracle);
        collateral = (collateral*newPrice)/btcEthPrice;
        btcEthPrice = newPrice;
    }


    function totalSupply() public view returns (uint) {
        return _totalSupply;
    }


    function registerOwner(bytes memory btcPublicKey) public {
        owners[msg.sender] = btcPublicKey;
    }
    
    function addCollateral() public payable onlyOwner{
        collateral += msg.value * btcEthPrice;
    }

    // This whole minting process could be replaced by an SPV verification of deposit, but given that there's already trust on CP, we will just piggyback on it for this.
    // The security model stays the same, the only difference that this will cause is that the CP will be able to increase the totalSupply without actually adding BTCs, whereas this would be impossible if we were to use SPV verifications
    function requestMint(uint amount, bytes memory userBtcPubKey) public returns (bool) {
        require( mints[msg.sender].amount == 0, "Previous minting operation has not been completed");
        mints[msg.sender] = Mint(amount, userBtcPubKey);
        _totalSupply += amount;
        require((100*collateral)/_totalSupply >= collateralRate, "Not enough collateral to maintain the rate");
    }
    
    function cancelMint(address minter) public onlyOwner {
        _totalSupply -= mints[minter].amount;
        mints[minter].amount = 0;
    }
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    
    function acceptMint(address minter, uint id) public onlyOwner {
        require(utxos[id].amount == 0, "Id is already in use");
        utxos[id] = Utxo(mints[minter].amount, minter);
        Transfer(address(0), minter,  mints[minter].amount);
        mints[minter].amount = 0;
    }
    
    function announceWithdraw(uint id) public {
        require(utxos[id].owner == msg.sender);
        _totalSupply -= utxos[id].amount;
        utxos[id].amount = 0;
    }
    
    // The same logic that was provided for the minting process applies also here. Again, we are piggybacking on CP trust.
    function ownerAnnounceWithdraw(uint id) onlyOwner public {
        _totalSupply -= utxos[id].amount;
        utxos[id].amount = 0;
    }
    
    function requestTransfer(address to, uint utxoId, uint transferId, bytes memory encryptedPrivateKey) public {
        require(transfers[transferId].utxoId == 0, "This transfer id is already in use");
        require(utxos[utxoId].owner == msg.sender, "Sender doesn't own the UTXO that it's trying to spend");
        transfers[transferId] = PendingTransfer(utxoId, msg.sender, to, encryptedPrivateKey);
    }
    
    // Used to deactivate old transfers that were not accepted
    function cancelTransfer(uint id) public{
        require(transfers[id].from == msg.sender);
        transfers[id].to = address(0);
    }
    
    // User checks that the encryptedPrivateKey provided is correct and, if so, accepts the transfer
    function acceptTransfer(uint id) public{
        require(msg.sender == transfers[id].to);
        Utxo storage utxo = utxos[transfers[id].utxoId];
        require(utxo.owner == transfers[id].from);
        transfers[id].to = address(0);
        utxo.owner = msg.sender;
    }
    
    // Missing: There are no fraud proofs for when CP signs a transaction that shouldn't be signed
    // The protocol still works without this, but it is not possible to punish CP if it misbehaves
    // Done in order to keep the implementation complexity of the prototype low

}
