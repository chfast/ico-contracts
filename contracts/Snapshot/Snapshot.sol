pragma solidity 0.4.15;

import './MPolicy.sol';


// Snapshot consumes MPolicy
contract Snapshot is MPolicy {

    ////////////////////////
    // Types
    ////////////////////////

    /// @dev `Checkpoint` is the structure that attaches a block number to a
    ///  given value, the block number attached is the one that last changed the
    ///  value
    struct Values {

        // `fromBlock` is the block number that the value was generated from
        uint256 snapshot;

        // `value` is the amount of tokens at a specific block number
        uint256 value;
    }

    ////////////////////////
    // Internal functions
    ////////////////////////

    function hasValue(
        Values[] storage values
    )
        internal
        constant
        returns (bool)
    {
        return values.length > 0;
    }

    function hasValueAt(
        Values[] storage values,
        uint256 _snapshot
    )
        internal
        constant
        returns (bool)
    {
        require(_snapshot < mNextSnapshotId());
        return values.length > 0 && values[0].snapshot <= _snapshot;
    }

    function getValue(
        Values[] storage values,
        uint256 _defaultValue
    )
        internal
        constant
        returns (uint256)
    {
        if (values.length == 0) {
            return _defaultValue;
        } else {
            uint256 last = values.length - 1;
            return values[last].value;
        }
    }

    /// @dev `getValueAt` retrieves the number of tokens at a given block number
    /// @param values The history of values being queried
    /// @param _snapshot The block number to retrieve the value at
    /// @return The number of tokens being queried
    function getValueAt(
        Values[] storage values,
        uint256 _snapshot,
        uint256 _defaultValue
    )
        internal
        constant
        returns (uint256)
    {
        require(_snapshot < mNextSnapshotId());

        // Empty value
        if (values.length == 0) {
            return _defaultValue;
        }

        // Shortcut for the out of bounds snapshots
        uint256 last = values.length - 1;
        uint256 lastSnapshot = values[last].snapshot;
        if (_snapshot >= lastSnapshot) {
            return values[last].value;
        }
        uint256 firstSnapshot = values[0].snapshot;
        if (_snapshot < firstSnapshot) {
            return _defaultValue;
        }

        // Binary search of the value in the array
        uint256 min = 0;
        uint256 max = last;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (values[mid].snapshot <= _snapshot) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return values[min].value;
    }

    /// @dev `setValue` used to update the `balances` map and the
    ///  `totalSupplyHistory`
    /// @param values The history of data being updated
    /// @param _value The new number of tokens
    function setValue(
        Values[] storage values,
        uint256 _value
    )
        internal
    {
        // TODO: simplify or break into smaller functions

        uint256 nextSnapshot = mNextSnapshotId();

        // Always create a new entry if there currently is no value
        bool empty = values.length == 0;
        if (empty) {

            // Create a new entry
            values.push(
                Values({
                    snapshot: nextSnapshot,
                    value: _value
                })
            );

            // Flag next snapshot as modified
            mFlagSnapshotModified();
            return;
        }

        uint256 last = values.length - 1;
        bool frozen = values[last].snapshot < nextSnapshot;
        if (frozen) {

            // Do nothing if the value was not modified
            bool unmodified = values[last].value == _value;
            if (unmodified) {
                return;
            }

            // Create new entry
            values.push(
                Values({
                    snapshot: nextSnapshot,
                    value: _value
                })
            );

            // Flag next snapshot as modified
            mFlagSnapshotModified();

        } else { // We are updating the nextSnapshot

            bool unmodifiedd = last > 0 && values[last - 1].value == _value;
            if (unmodifiedd) {
                // Remove nextSnapshot entry
                delete values[last];
                values.length--;
                return;
            }

            // Overwrite next snapshot entry
            values[last].value = _value;
        }
    }
}
