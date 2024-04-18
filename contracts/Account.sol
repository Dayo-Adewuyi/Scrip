pragma solidity ^0.8.9;

import "@account-abstraction/contracts/core/EntryPoint.sol";
import "@account-abstraction/contracts/interfaces/IAccount.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

interface ERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Account is IAccount {
    uint256 public count;
    address public owner;
    mapping(address => uint256) public balances;

    constructor(address _owner) {
        owner = _owner;
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        view
        returns (uint256 validationData)
    {
        address recovered = ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature);

        return owner == recovered ? 0 : 1;
    }

    function execute() external {
        count++;
    }

    function sendTokens(address tokenAddress, address recipient, uint256 amount) external {
        require(balances[tokenAddress] >= amount, "Insufficient balance");
        balances[tokenAddress] -= amount;
        ERC20(tokenAddress).transfer(recipient, amount);
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        ERC20(tokenAddress).transfer(address(this), amount);
        balances[tokenAddress] += amount;
    }
}

contract AccountFactory {
    mapping(uint => address) public phoneNumberToAccount;

    function createAccount(address owner, uint phoneNumber) external returns (address) {
        require(phoneNumberToAccount[phoneNumber] == address(0), "Account already exists for this phone number");

        bytes32 salt = bytes32(uint256(uint160(owner)));
        bytes memory creationCode = type(Account).creationCode;
        bytes memory bytecode = abi.encodePacked(creationCode, abi.encode(owner));

        address addr = Create2.computeAddress(salt, keccak256(bytecode));
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            phoneNumberToAccount[phoneNumber] = addr;
            return addr;
        }

        addr = deploy(salt, bytecode);
        phoneNumberToAccount[phoneNumber] = addr;
        return addr;
    }

    function deploy(bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        require(bytecode.length != 0, "Create2: bytecode length is zero");
        /// @solidity memory-safe-assembly
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "Create2: Failed on deploy");
    }
}
