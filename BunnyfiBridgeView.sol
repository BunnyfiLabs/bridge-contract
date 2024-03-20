// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
 import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BunnyfiBridgeView is Ownable, Nonces {
    mapping(address => bool) public ProxyAdmins;

    struct BridgeIdInfo {
        address[] router;
        address[] asset;
        bool bridgestatus;
    }

    mapping(uint256 => BridgeIdInfo) public BridgeId;
    //BridgeId is chainid

    mapping(address => bool) public UserBlackList;

    event SetIdInfo(uint256 indexed chainid, BridgeIdInfo BridgeId);
    event SetProxyAdmin(address indexed user, bool status);
    event SetUserBlackStatus(
        address indexed admin,
        uint256 nonce,
        uint256 chainid,
        address user,
        bool status
    );
    event Withdraw(address indexed admin, uint256 amount);
    event WithdrawOtherTokens(address indexed admin, address wtoken,address  to, uint256 amount);

    function getChainIdInfoRouter(uint256 chainid)
        public
        view
        returns (address[] memory router)
    {
        router = BridgeId[chainid].router;
    }

    function getChainIdInfoAsset(uint256 chainid)
        public
        view
        returns (address[] memory asset)
    {
        asset = BridgeId[chainid].asset;
    }

    function getAssetBalance()
        public
        view
        returns (uint256[] memory assetbalance)
    {
        assetbalance = new uint256[](BridgeId[block.chainid].asset.length);
        for (uint256 i = 0; i < BridgeId[block.chainid].asset.length; i++) {
            assetbalance[i] = IERC20(BridgeId[block.chainid].asset[i])
                .balanceOf(address(this));
        }
    }

    function setIdInfoByOwner(uint256 chainid, BridgeIdInfo memory info)
        external
        onlyOwner
    {
        BridgeId[chainid] = info;
        emit SetIdInfo(chainid, info);
    }

    function setProxyAdmin(address admin, bool status) public onlyOwner {
        ProxyAdmins[admin] = status;
        emit SetProxyAdmin(admin, status);
    }

    function setUserBlackStatus(
        address user,
        bool status,
        bytes memory signature
    ) external {
        // check
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender,
                user,
                status,
                _useNonce(msg.sender),
                block.chainid
            )
        );
        address adminAddress = ECDSA.recover(hash, signature);
        require(
            adminAddress != address(0) &&
                ProxyAdmins[adminAddress] == true,
            "signer error"
        );
        require(UserBlackList[user] != status, "Error Set User Status");
        UserBlackList[user] = status;
        emit SetUserBlackStatus(
            msg.sender,
            _useNonce(msg.sender),
            block.chainid,
            user,
            status
        );
    }

    function setUserBlackList(address[] memory users, bytes memory signature)
        external
    {
        // check
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender,
                users,
                _useNonce(msg.sender),
                block.chainid
            )
        );
        address adminAddress = ECDSA.recover(hash, signature);
        require(
            adminAddress != address(0) &&
                ProxyAdmins[adminAddress] == true,
            "signer error"
        );
        for (uint256 i = 0; i < users.length; i++) {
            UserBlackList[users[i]] = true;
            emit SetUserBlackStatus(
                msg.sender,
                _useNonce(msg.sender),
                block.chainid,
                users[i],
                true
            );
        }
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(payable(address(this)).balance);
        emit Withdraw(msg.sender, payable(address(this)).balance);
    }

    function withdrawOtherTokens( address wtoken,address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(wtoken), to, amount);
        emit WithdrawOtherTokens(msg.sender, wtoken, to, amount);
    }

    receive() external payable {}
}
