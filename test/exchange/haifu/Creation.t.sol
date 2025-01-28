pragma solidity >=0.8;

import {MockToken} from "@standardweb3/mock/MockToken.sol";
import {MockBase} from "@standardweb3/mock/MockBase.sol";
import {MockQuote} from "@standardweb3/mock/MockQuote.sol";
import {MockUSDC} from "@standardweb3/mock/MockUSDC.sol";
import {MockBTC} from "@standardweb3/mock/MockBTC.sol";
import {ErrToken} from "@standardweb3/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "@standardweb3/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "@standardweb3/exchange/orderbooks/OrderbookFactory.sol";
import {IOrderbook} from "@standardweb3/exchange/interfaces/IOrderbook.sol";
import {Orderbook} from "@standardweb3/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "@standardweb3/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "@standardweb3/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "@standardweb3/mock/WETH9.sol";
import {BaseSetup} from "./HaifuLaunchpadSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {IHaifu} from "../../../../src/interfaces/IHaifu.sol";

interface IERC20 {
    function symbol() external view returns (string memory);

    function approve(address spender, uint256 amount) external returns (bool);

    function name() external view returns (string memory);
}

contract HaifuCreationTest is BaseSetup {
    // test launch haifu
    function testHaifuLaunch() public {
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });

        // create haifu
        launchpad.launchHaifu("Haifu", "HAI", state);
    }

    // test created haifu name and symbol matches the argument
    function testHaifuNameSymbol() public {
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });

        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        // check haifu name and symbol
        assertEq(IERC20(haifu).name(), "Haifu");
        assertEq(IERC20(haifu).symbol(), "HAI");
    }

    // test if commit works in haifu in accepting fund phase
    function testHaifuCommitWorksBeforeAcceptingFunds() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);

        // commit to haifu
        weth.deposit{value: 1000e18}();
        weth.approve(address(launchpad), 1000e18);
        launchpad.commit(haifu, address(weth), 1000e18);
    }

    // test if commit does not work after fund accepting phase
    function testHaifuCommitRevertsAfterAcceptingFunds() public {
        utils.setTime(1100001);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);

        // commit to haifu
        weth.deposit{value: 1000e18}();
        weth.approve(address(launchpad), 1000e18);
        vm.expectRevert();
        launchpad.commit(haifu, address(weth), 1000e18);
    }

    // test if withdraw works in haifu in accepting fund phase
    function testHaifuWithdrawWorksBeforeAcceptingFunds() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);

        // commit to haifu
        weth.deposit{value: 1000e18}();
        weth.approve(address(launchpad), 1000e18);
        launchpad.commit(haifu, address(weth), 1000e18);

        // withdraw from haifu
        IERC20(haifu).approve(address(launchpad), 1e18);
        launchpad.withdraw(haifu, 1e18);
    }

    // test if withdraw does not work after fund accepting phase
    function testHaifuWithdrawRevertsAfterAcceptingFunds() public {
        utils.setTime(1100);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);

        // commit to haifu
        weth.deposit{value: 1000e18}();
        weth.approve(address(launchpad), 1000e18);
        launchpad.commit(haifu, address(weth), 1000e18);

        utils.setTime(1100001);
        // withdraw from haifu
        IERC20(haifu).approve(address(launchpad), 1e18);
        vm.expectRevert();
        launchpad.withdraw(haifu, 1e18);
    }

    // test if open does not work before fund accepting phase
    function testOpenRevertsBeforeFundAcceptingPhase() public {
        utils.setTime(1100);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        vm.expectRevert();
        launchpad.openHaifu(haifu);
    }

    // test if open reverts in haifu after accepting fund phase with failure
    function testOpenRevertsAfterAcceptingFundPhaseWithFailure() public {
        utils.setTime(1100001);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 1000000e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        vm.expectRevert();
        launchpad.openHaifu(haifu);
    }

    // test if open works in haifu after accepting fund phase with success
    function testOpenWorksAfterAcceptingFundPhaseWithSuccess() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);
        // commit with success
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 10e18);

        utils.setTime(1100001);

        launchpad.openHaifu(haifu);
    }

    // test if expire reverts before fund expiary date on successful fundraise
    function testExpireRevertsAfterAcceptingFundPhaseWithSuccess() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);
        // commit with success
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 10e18);

        utils.setTime(1100001);

        IHaifu(haifu).raised();

        vm.expectRevert();
        launchpad.expireHaifu(haifu, address(weth));
    }

    // test if expire works after fund expiary date
    function testExpireWorksAfterFundExpiaryDate() public {
        utils.setTime(1001);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);
        // commit with success
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 10e18);

        utils.setTime(1200001);

        launchpad.expireHaifu(haifu, address(weth));
    }

    // test if expire works after fund expiary date with failure
    function testExpireWorksAfterFundExpiaryDateOnFailure() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        launchpad.setWhitelist(haifu, address(this), true);
        // commit with failure
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 1e18);

        utils.setTime(1100001);

        launchpad.expireHaifu(haifu, address(weth));
    }

    // test if claim does not work before fund expiary date
    function testClaimRevertsBeforeFundExpiaryDate() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        // set whitelist
        launchpad.setWhitelist(haifu, address(this), true);

        // commit with success
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 10e18);

        IERC20(haifu).approve(address(launchpad), 10000e18);
        vm.expectRevert();
        launchpad.claimExpiary(haifu, 100);
    }

    // test if claim works after fund expiary date
    function testClaimWorksAfterFundExpiaryDateOnFailure() public {
        utils.setTime(1000);
        super.setUp();
        // build struct for haifu
        IHaifu.State memory state = IHaifu.State({
            totalSupply: 1000000000e18,
            // carry in fraction of 1e8
            carry: 1e7,
            fundManager: address(booker),
            deposit: address(weth),
            // {haifu token} / {deposit token}
            depositPrice: 1000e8,
            raised: 0,
            goal: 10e18,
            HAIFU: address(HAIFU),
            // {haifu token} / {$HAIFU}
            haifuPrice: 1000e8,
            haifuGoal: 1000000e18,
            haifuRaised: 0,
            fundAcceptingExpiaryDate: 1100000,
            fundExpiaryDate: 1200000
        });
        // create haifu
        address haifu = launchpad.launchHaifu("Haifu", "HAI", state);

        // set whitelist
        launchpad.setWhitelist(haifu, address(this), true);

        // commit with success
        weth.deposit{value: 100e18}();
        weth.approve(address(launchpad), 100e18);
        launchpad.commit(haifu, address(weth), 1e18);

        // open Haifu
        utils.setTime(1100001);
        vm.expectRevert();
        launchpad.openHaifu(haifu);

        // expire Haifu
        launchpad.expireHaifu(haifu, address(weth));


        IERC20(haifu).approve(address(launchpad), 10000e18);
        launchpad.claimExpiary(haifu, 1e15);
    }
}
