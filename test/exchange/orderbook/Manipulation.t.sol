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

contract ManipulationTest is BaseSetup {
    function testManipulateMarketPrice() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 90e8, 0, address(token1));
        vm.prank(trader1);
        matchingEngine.limitSell(address(token1), address(token2), 90e8, 100e18, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 110e8, 100e18, true, 2, trader1);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        console.log("Market price before manipulation: ", book.mktPrice());
        vm.prank(attacker);
        //book.placeBid(address(trader1), 1e7, 100e18);
        //vm.prank(attacker);
        //book.placeAsk(address(trader1), 1e8, 100e18);
        console.log("Market price after manipulation:", book.mktPrice());
    }
}
