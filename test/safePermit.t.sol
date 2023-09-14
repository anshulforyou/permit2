pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Permit2} from "../src/Permit2.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import "safe-tools/SafeTestTools.sol";

contract SafePermitTest is Test, SafeTestTools {
    using SafeTestLib for SafeInstance;

    SafeInstance safe;
    Permit2 permitContract;

    address admin = address(0x1);
    address user1;
    uint256 user1PrivKey;
    address user2 = address(0x3);
    MockERC20 token;

    bytes32 PERMIT2_DOMAIN_SEPARATOR;

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    bytes32 public constant SAFE_MSG_TYPEHASH = keccak256("SafeMessage(bytes message)");

    function setUp() public {
        vm.startPrank(admin); // impersonate admin
        user1PrivKey = 0x12341234;
        user1 = vm.addr(user1PrivKey);
        permitContract = new Permit2();

        PERMIT2_DOMAIN_SEPARATOR = permitContract.DOMAIN_SEPARATOR();

        uint256[] memory owners = new uint256[](1);
        owners[0] = user1PrivKey;
        safe = _setupSafe(owners, 1);

        token = new MockERC20("Mock", "MCK", 18);
        token.mint(user1, 1000);
        vm.stopPrank();
    }

    function testSafePermit() public {
        vm.startPrank(user1);
        token.transfer(address(safe.safe), 1000);
        assertEq(token.balanceOf(address(safe.safe)), 1000);
        vm.stopPrank();

        safe.execTransaction({
            to: address(token),
            value: 0,
            data: abi.encodeWithSelector(token.approve.selector, address(permitContract), 1000)
        });

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token), amount: 1000}),
            nonce: 0,
            deadline: 100
        });

        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));

        bytes memory transactionData = abi.encodePacked(
            "\x19\x01",
            PERMIT2_DOMAIN_SEPARATOR,
            keccak256(
                abi.encode(
                    _PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, address(this), permit.nonce, permit.deadline
                )
            )
        );

        // (, bytes32 r, bytes32 s) = safe.signTransaction(
        //     encodeSmartContractWalletAsPK(address(safe.safe)),
        //     address(permitContract),
        //     0,
        //     transactionData,
        //     Enum.Operation.Call,
        //     0,
        //     0,
        //     0,
        //     address(0),
        //     address(0)
        // );

        // bytes memory signature = abi.encodePacked(r, s, bytes1(0));

        // safe.EIP1271Sign(transactionData);
        safe.EIP1271Sign(0xc4c2f8f8140b008910b3f66a6cc8e3049cd183e3e794d44bcd011fc1cde0e3a7);

        // safe.safe.isValidSignature(transactionData, "");

        // require(1 < 0, "reverting here");

        ISignatureTransfer.SignatureTransferDetails memory transferDetails =
            ISignatureTransfer.SignatureTransferDetails({to: user2, requestedAmount: 100});

        permitContract.permitTransferFrom(
            permit,
            transferDetails,
            address(safe.safe),
            // "0x451e9e6b1425716b5ab4ea2d8f26ae0c762a7a955bc704b95d8d750158cba04d"
            ""
        );

        assertEq(token.balanceOf(address(safe.safe)), 900);
        assertEq(token.balanceOf(user2), 100);
    }
}
