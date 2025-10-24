// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title NoteCommitmentTree
/// @notice config skeleton for an append-only merkle tree of note commitments
/// @dev NoteCommitmentTree encodes the domain(notes/commitments) and the data structure(merkle tree).
contract NoteCommitmentTree {
    /// @notice tree height (levels)
    uint8 public immutable levels;

    /// @notice Next free leaf index. Starts at 0
    /// @dev nextIndex is set once in the constructor and cannot change afterward (hence immutable).
    ///      it is not stored as standard storage (so no SLOAD at read) so it is cheaper to read than storage.
    uint256 public  immutable nextIndex;

    /// @notice Emitted once so off-chain tools can pin initial config.
    event TreeConfigured(uint8 levels);

    /// @notice Per-level "zero" node values (level 0,1,2,...,levels-1).
    /// @dev For educational purposes we derive zeros via keccak(left,right).
    /// Merkle trees need a “default” value at each level. when the tree is empty, every missing sibling is a zero value. 
    ///     computing a root then is just repeatedly hashing (z,z) from level 0 up to the top.
    bytes32[] public zeroes;

    /// @notice per-level scratch space for the latest "left" partial subtree. 
    /// as you append leaves one by one, you keep a scratch pad at each level that remembers “the most recent left child we saw that hasn’t yet been paired.” 
    /// Tornado-style Merkle trees call this array filledSubtrees.
    /// @dev initialized to zeros for an empty tree, mutated during the inserts
    bytes32[] public filledSubtrees;

    /// @notice The current root for the (so far) empty tree.
    /// @dev it is empty since we have no inserts yet.
    bytes32 public currentRoot;
    /// @notice Emitted once after zero-values are initialized and empty root is set.
    event EmptyRootInitialized(bytes32 root);


    /// @param _levels The merkle tree height.
    constructor(uint8 _levels) {
        require(_levels > 0 && _levels <= 64,"levels out of range");
        levels = _levels;
        nextIndex = 0;
        emit TreeConfigured(levels);

        // compute per-level zeros and empty root
        zeroes = new bytes32[](_levels);

        // level-0 zero: setting to 0x00..00 for now
        bytes32 z = bytes32(0);

        // store zero for each level, and derieve next by hashing (z,z)
        for (uint i = 0; i< _levels; i++){
            zeroes[i] = z;
            z = _hashPair(z,z);
        }

        // after the loop, z is the "top" zero => empty-tree root
        currentRoot = z;
        emit EmptyRootInitialized(z);

        // initialize filledSubtrees to zeros for an empty subtree
        filledSubtrees = new bytes32[](_levels);
        for (uint8 j = 0; j < _levels; j++){
            filledSubtrees[j] = zeroes[j];
        }
    }

    function _hashPair(bytes32 left, bytes32 right) internal pure returns (bytes32){
        return keccak256(abi.encode(left, right));
    }

       /// @notice Returns the current Merkle root.
    /// @dev stateMutability: view (reads storage, no writes).
    /// we mark it pure because it only uses its inputs and does no storage or state access.
    function getCurrentRoot() external view returns (bytes32) {
        return currentRoot; // single SLOAD at runtime
    }

    /// When you call getCurrentRoot(), the EVM performs a single SLOAD to read currentRoot from its storage slot. 
    /// view does not mean “no SLOADs”; it only means “no SSTOREs / no state mutation.”
    /// for immutable levels: reads will not do an SLOAD, compiler inlines the constructor-set value into code paths
    /// on calling this func getCurrentRoot() we can spot the SLOAD where the storage root is read.
}

