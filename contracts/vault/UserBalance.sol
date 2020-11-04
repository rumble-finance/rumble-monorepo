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

pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

import "../vendor/EnumerableSet.sol";

import "./IVault.sol";
import "./VaultAccounting.sol";
import "./PoolRegistry.sol";

import "../math/FixedPoint.sol";

abstract contract UserBalance is IVault, VaultAccounting {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FixedPoint for uint128;

    mapping(address => mapping(address => uint128)) internal _userTokenBalance; // user -> token -> user balance

    // Operators are allowed to use a user's tokens in a swap
    mapping(address => EnumerableSet.AddressSet) private _userOperators;

    // Trusted operators are operators for all users, without needing to be authorized. Trusted operators cannot be
    // revoked.
    EnumerableSet.AddressSet private _trustedOperators;

    // Trusted operators reporters can report new trusted operators
    EnumerableSet.AddressSet internal _trustedOperatorReporters;

    event Deposited(
        address indexed depositor,
        address indexed user,
        address indexed token,
        uint128 amount
    );

    event Withdrawn(
        address indexed user,
        address indexed recipient,
        address indexed token,
        uint128 amount
    );

    event AuthorizedOperator(address indexed user, address indexed operator);
    event RevokedOperator(address indexed user, address indexed operator);

    event AuthorizedTrustedOperator(address indexed operator);

    function getUserTokenBalance(address user, address token)
        public
        override
        view
        returns (uint128)
    {
        return _userTokenBalance[user][token];
    }

    function deposit(
        address token,
        uint128 amount,
        address user
    ) external override {
        // Pulling from the sender - no need to check for operators
        uint128 received = _pullTokens(token, msg.sender, amount);

        // TODO: check overflow
        _userTokenBalance[user][token] = _userTokenBalance[user][token].add128(
            received
        );
        emit Deposited(msg.sender, user, token, received);
    }

    function withdraw(
        address token,
        uint128 amount,
        address recipient
    ) external override {
        require(
            _userTokenBalance[msg.sender][token] >= amount,
            "Vault: withdraw amount exceeds balance"
        );

        _userTokenBalance[msg.sender][token] -= amount;
        _pushTokens(token, recipient, amount);

        emit Withdrawn(msg.sender, recipient, token, amount);
    }

    function authorizeOperator(address operator) external override {
        if (_userOperators[msg.sender].add(operator)) {
            emit AuthorizedOperator(msg.sender, operator);
        }
    }

    function revokeOperator(address operator) external override {
        if (_userOperators[msg.sender].remove(operator)) {
            emit RevokedOperator(msg.sender, operator);
        }
    }

    function isOperatorFor(address user, address operator)
        public
        override
        view
        returns (bool)
    {
        return
            (user == operator) ||
            _trustedOperators.contains(operator) ||
            _userOperators[user].contains(operator);
    }

    function getUserTotalOperators(address user)
        external
        override
        view
        returns (uint256)
    {
        return _userOperators[user].length();
    }

    function getUserOperators(
        address user,
        uint256 start,
        uint256 end
    ) external override view returns (address[] memory) {
        require(
            (end >= start) && (end - start) <= _userOperators[user].length(),
            "Bad indices"
        );

        // Ideally we'd use a native implemenation: see
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2390
        address[] memory operators = new address[](end - start);

        for (uint256 i = 0; i < operators.length; ++i) {
            operators[i] = _userOperators[user].at(i + start);
        }

        return operators;
    }

    function getTotalTrustedOperators()
        external
        override
        view
        returns (uint256)
    {
        return _trustedOperators.length();
    }

    function getTrustedOperators(uint256 start, uint256 end)
        external
        override
        view
        returns (address[] memory)
    {
        require(
            (end >= start) && (end - start) <= _trustedOperators.length(),
            "Bad indices"
        );

        // Ideally we'd use a native implemenation: see
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2390
        address[] memory operators = new address[](end - start);

        for (uint256 i = 0; i < operators.length; ++i) {
            operators[i] = _trustedOperators.at(i + start);
        }

        return operators;
    }

    function getTotalTrustedOperatorReporters()
        external
        override
        view
        returns (uint256)
    {
        return _trustedOperatorReporters.length();
    }

    function getTrustedOperatorReporters(uint256 start, uint256 end)
        external
        override
        view
        returns (address[] memory)
    {
        require(
            (end >= start) &&
                (end - start) <= _trustedOperatorReporters.length(),
            "Bad indices"
        );

        // Ideally we'd use a native implemenation: see
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2390
        address[] memory operatorReporters = new address[](end - start);

        for (uint256 i = 0; i < operatorReporters.length; ++i) {
            operatorReporters[i] = _trustedOperatorReporters.at(i + start);
        }

        return operatorReporters;
    }

    function reportTrustedOperator(address operator) external override {
        require(
            _trustedOperatorReporters.contains(msg.sender),
            "Caller is not trusted operator reporter"
        );

        if (_trustedOperators.add(operator)) {
            emit AuthorizedTrustedOperator(operator);
        }
    }
}