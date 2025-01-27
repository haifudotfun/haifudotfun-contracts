pragma solidity >=0.8;

import {MockToken} from "@standardweb3/mock/MockToken.sol";
import {MockBase} from "@standardweb3/mock/MockBase.sol";
import {MockQuote} from "@standardweb3/mock/MockQuote.sol";
import {MockBTC} from "@standardweb3/mock/MockBTC.sol";
import {ErrToken} from "@standardweb3/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "@standardweb3/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "@standardweb3/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "@standardweb3/exchange/orderbooks/Orderbook.sol";
import {IOrderbook} from "@standardweb3/exchange/interfaces/IOrderbook.sol";
import {ExchangeOrderbook} from "@standardweb3/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "@standardweb3/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "@standardweb3/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract LimitOrderTest is BaseSetup {
    // rematch order so that amount is changed from the exact order
    function testRematchOrderAmountIncrease() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) = matchingEngine
            .limitBuy(
                address(token1),
                address(btc),
                1e8,
                1e8,
                true,
                2,
                trader1
            );
        // rematch trade
        vm.prank(trader1);
        matchingEngine.rematchOrder(
            address(token1),
            address(btc),
            true,
            ord0Id,
            1e8,
            1e10,
            5
        );
    }

    function testRematchOrderAmountDecrease() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) = matchingEngine
            .limitBuy(
                address(token1),
                address(btc),
                1e8,
                1e8,
                true,
                2,
                trader1
            );
        // rematch trade
        vm.prank(trader1);
        matchingEngine.rematchOrder(
            address(token1),
            address(btc),
            true,
            ord0Id,
            1e8,
            1e5,
            5
        );
    }

    // rematch order so that price is changed from the exact order
    function testRematchOrderPrice() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) = matchingEngine
            .limitBuy(
                address(token1),
                address(btc),
                1e8,
                1e8,
                true,
                2,
                trader1
            );
        // rematch trade
        vm.prank(trader1);
        matchingEngine.rematchOrder(
            address(token1),
            address(btc),
            true,
            ord0Id,
            1e5,
            1e10,
            5
        );
    }
}
