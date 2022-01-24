// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;

import "../PremintedGauge.sol";

interface IPolygonRootChainManager {
    function depositFor(
        address user,
        IERC20 token,
        bytes calldata depositData
    ) external;
}

contract PolygonRootGauge is PremintedGauge {
    IPolygonRootChainManager private immutable _polygonRootChainManager;
    address private immutable _polygonERC20Predicate;

    address private immutable _recipient = address(this);

    constructor(
        IBalancerMinter minter,
        IPolygonRootChainManager polygonRootChainManager,
        address polygonERC20Predicate
    ) PremintedGauge(minter) {
        _polygonRootChainManager = polygonRootChainManager;
        _polygonERC20Predicate = polygonERC20Predicate;
    }

    function _postMintAction(uint256 mintAmount) internal override {
        // Token needs to be approved on the predicate NOT the main bridge contract
        _balToken.approve(_polygonERC20Predicate, mintAmount);

        // This will transfer BAL to `_recipient` on the Polygon chain
        _polygonRootChainManager.depositFor(_recipient, _balToken, abi.encode(mintAmount));
    }
}
