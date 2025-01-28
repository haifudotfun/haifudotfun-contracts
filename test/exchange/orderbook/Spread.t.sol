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
import {ExchangeOrderbook} from "@standardweb3/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "@standardweb3/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "@standardweb3/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract OrderSpreadTest is BaseSetup {
    function testLimitOrder() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 3632e8, 0, address(token1));
        vm.prank(booker);
        address base = address(token1);
        address quote = address(token2);
        console.log("Base/Quote Pair: ", matchingEngine.getPair(base, quote));
        vm.prank(trader1);
        matchingEngine.limitBuy(base, quote, 3632e8, 100e18, true, 2, trader1);
        book = Orderbook(payable(matchingEngine.getPair(base, quote)));
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        vm.prank(trader2);
        matchingEngine.limitSell(base, quote, 10000e8, 100e18, true, 2, trader2);
        console.log(matchingEngine.mktPrice(base, quote));
    }

    function testLimitSellSpread() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 3632e8, 0, address(token1));
        vm.prank(booker);
        address base = address(token1);
        address quote = address(token2);
        console.log("Base/Quote Pair: ", matchingEngine.getPair(base, quote));
        vm.prank(trader1);
        matchingEngine.limitSell(base, quote, 3632e8, 100e18, true, 2, trader1);
        book = Orderbook(payable(matchingEngine.getPair(base, quote)));
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        vm.prank(trader2);
        matchingEngine.limitSell(base, quote, 0e8, 100e18, true, 2, trader2);
        console.log(matchingEngine.mktPrice(base, quote));
    }

    function testLimitSellSpreadMatchesWithExactPrice() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 3632e8, 0, address(token1));
        vm.prank(trader1);
        address base = address(token1);
        address quote = address(token2);
        matchingEngine.limitSell(base, quote, 3632e8, 100e18, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(base, quote, 3632e8, 100e18, true, 2, trader1);
    }
}
