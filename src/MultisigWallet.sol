// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract MultisigWallet {
    // 多签钱包持有人的地址
    address[] public owners;
    // 多签钱包持有人的数量
    uint256 public ownerCount;
    // 多签执行门槛，至少交易有n个多签人签名才能被执行
    uint256 public threshold;
    // 初始为0，随着多签合约每笔执行的交易递增的值，可以防止签名重放攻击
    uint256 public nonce;
    // 记录一个地址是否为多签持有人
    mapping (address => bool) public isOwner;




    // 交易成功事件
    event ExecutionSuccess(bytes32 txHash);
    // 交易失败事件
    event ExecutionFailure(bytes32 txHash);

    constructor() {
        
    }

    function _setupOwners(address[] memory _owners, uint256 _threshold) internal {
        require(_threshold == 0,"threshold has been initialized");
        // 多签执行门槛要小于多签人数
        require(_threshold <= _owners.length,"_threshold must less than _owners.length");
        require(_threshold >= 1 ,"_threshold must >= 1");

        for(uint256 i=0; i < _owners.length; i++){
            address owner = _owners[i];
            // 多签人不能为0地址，本合约地址，不能重复
            require(owner != address(0) && !isOwner[owner] && owner != address(this)," owner is invalid");
            owners.push(owner);
            isOwner[owner] = true;
        }
        ownerCount = _owners.length;
        threshold = _threshold;

    }

    function execTransaction(address to, uint256 value, 
    bytes memory data, bytes memory signatures) public payable virtual returns (bool success) {
        bytes32 txHash = encodeTransactionData(to,value,data,nonce,block.chainid);
        nonce++;
        checkSignatures(txHash,signatures);
        // 利用call执行交易 并获取交易结果
        (success, ) = to.call{value: value}(data);
        require(success, "execTransaction failed");
        if (success) {
            emit ExecutionSuccess(txHash);
        }else{
            emit ExecutionFailure(txHash);
        }

    }

    function checkSignatures(
        bytes32 dataHash,
        bytes memory signatures
    ) public view {
        uint256 _threshold = threshold;
        require(_threshold > 0, "_threshold must >= 1");
        // 检查签名长度足够长
        require(signatures.length > _threshold * 65,"signatures length not enough");

        // 通过一个循环，检查收集到的签名是否有效
        // 大概思路
        // 1. 用ECDSA先验证签名是否有效
        // 2. 利用currentOwner > LastOwner 确定签名来自不对多签 （多签地址递增）
        // 3. 利用isOwner[currentOwner] 确定签名者为多签持有人

        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for(i=0; i< _threshold; i++){
            (v,r,s) = signatureSplit(signatures,i);
            // 利用ecrecover检查签名是否有效
            currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v, r, s);
            require(currentOwner > lastOwner && isOwner[currentOwner],"WTF5007");
            lastOwner = currentOwner;
        }
    }

    function signatureSplit(bytes memory signatures, uint256 pos) 
    internal pure returns(
        uint8 v, bytes32 r, bytes32 s
    ){
        // 签名的格式: {bytes32 r} {bytes32 s} {bytes32 v}
        assembly {
            let signaturePos := mul(0x41,pos)
            r := mload(add(signatures, add(signatures, 0x20)))
            s := mload(add(signatures, add(signatures, 0x40)))
            v := and(mload(add(signatures, add(signaturePos,0x41))),0xff)
        }
    }


    function encodeTransactionData(
        address to, uint256 value, 
        bytes memory data, 
        uint256 _nonce, uint256 chainId) public pure returns (bytes32){
            bytes32 safeTxHash = keccak256(abi.encode(
                to, value, keccak256(data), _nonce, chainId
            ));

            return safeTxHash;
        }
}