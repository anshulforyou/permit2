pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Permit2} from "../src/Permit2.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import "safe-tools/SafeTestTools.sol";
import {Dapp} from "../src/dapp/dapp.sol";
import {Utils} from "./utils/Permit2Adapter.sol";
import {IArbitraryExecutionPermit2Adapter} from
    "../src/module/permit2-adapter/interfaces/IArbitraryExecutionPermit2Adapter.sol";
import {IPermit2} from "../src/module/permit2-adapter/interfaces/external/IPermit2.sol";
import {UniversalPermit2Adapter} from "../src/module/permit2-adapter/UniversalPermit2Adapter.sol";

contract SafePermitTest is Test, SafeTestTools {
    using SafeTestLib for SafeInstance;

    SafeInstance safe;
    Permit2 permitContract;
    UniversalPermit2Adapter adapter;
    Dapp targetDapp;

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

        adapter = new UniversalPermit2Adapter(IPermit2(address(permitContract)));

        PERMIT2_DOMAIN_SEPARATOR = permitContract.DOMAIN_SEPARATOR();

        uint256[] memory owners = new uint256[](1);
        owners[0] = user1PrivKey;
        safe = _setupSafe(owners, 1);

        token = new MockERC20("Mock", "MCK", 18);
        token.mint(user1, 1000);
        targetDapp = new Dapp(address(token));
        vm.stopPrank();
    }

    function testSafePermitAdapter() public {
        vm.startPrank(user1);
        token.transfer(address(safe.safe), 1000);
        assertEq(token.balanceOf(address(safe.safe)), 1000);
        vm.stopPrank();

        safe.execTransaction({
            to: address(token),
            value: 0,
            data: abi.encodeWithSelector(token.approve.selector, address(permitContract), 1000)
        });

        vm.startPrank(address(safe.safe));
        safe.EIP1271Sign(0xfaf3a3894dbf5defa58074b62ff53603bbad2565d39b88cff7e63ed4736a9123);

        IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit = Utils.buildPermit(address(token), 100, 0, "");
        IArbitraryExecutionPermit2Adapter.AllowanceTarget[] memory _allowanceTargets =
            Utils.buildAllowanceTargets(address(targetDapp), address(token));
        IArbitraryExecutionPermit2Adapter.ContractCall[] memory _contractCalls = Utils.buildContractCalls(
            address(targetDapp), abi.encodeWithSelector(targetDapp.collectTokens.selector, 100), 0
        );

        (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit(
            _permit, _allowanceTargets, _contractCalls, Utils.buildEmptyTransferOut(), type(uint256).max
        );
        vm.stopPrank();
    }
}
