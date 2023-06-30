// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    // Variables
    uint private transactionId;
    address[] private owners;
    uint private numConfirmationsRequired;

    // Struct for individual transactions
    struct Transaction {
        address to;
        uint value;
        bool executed;
        mapping (address => bool) isConfirmed;
    }

    // Array of Transactions
    Transaction[] private transactions;

    // Mapping of address to isOwner boolean
    mapping (address => bool) private isOwner;

    // Constructor function to initialize owners and set numConfirmationsRequired
    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners are required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "Invalid number of confirmations required");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Duplicate owner address");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // Modifier to allow only owners to execute certain functions
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only owners are allowed to perform this action");
        _;
    }

    // Events
    event Deposit(address indexed sender, uint value);
    event NewTransaction(uint indexed transactionId, address indexed to, uint value);
    event Confirmation(address indexed owner, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    // Fallback function to receive ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // Function to get the list of owners
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // Function to get the number of confirmations required
    function getNumConfirmationsRequired() public view returns (uint) {
        return numConfirmationsRequired;
    }

    // Function to get the total number of transactions
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
   
}

// Function to get transaction details
function getTransaction(uint _transactionId)
    public
    view
    returns (address to, uint value, bool executed, uint numConfirmations)
{
    Transaction storage transaction = transactions[_transactionId];
    return (transaction.to, transaction.value, transaction.executed, getConfirmationCount(_transactionId));
}

// Function to get the number of confirmations for a specific transaction
function getConfirmationCount(uint _transactionId) public view returns (uint) {
    uint count = 0;
    Transaction storage transaction = transactions[_transactionId];
    for (uint i = 0; i < owners.length; i++) {
        address owner = owners[i];
        if (transaction.isConfirmed[owner]) {
            count += 1;
        }
    }
    return count;
}

// Function to create a new transaction
function createTransaction(address _to, uint _value)
    public
    onlyOwner
    returns (uint)
{
    require(_to != address(0), "Invalid destination address");
    require(address(this).balance >= _value, "Insufficient balance");

    uint id = transactions.length;

    Transaction memory transaction = Transaction({
        to: _to,
        value: _value,
        executed: false
    });

    transactions.push(transaction);

    emit NewTransaction(id, _to, _value);

    return id;
}

// Function to confirm a transaction
function confirmTransaction(uint _transactionId) public onlyOwner {
    require(_transactionId < transactions.length, "Invalid transaction ID");
    Transaction storage transaction = transactions[_transactionId];
    require(!transaction.isConfirmed[msg.sender], "Transaction already confirmed");

    transaction.isConfirmed[msg.sender] = true;

    emit Confirmation(msg.sender, _transactionId);

    if (getConfirmationCount(_transactionId) >= numConfirmationsRequired) {
        executeTransaction(_transactionId);
    }
}

// Function to execute a transaction
function executeTransaction(uint _transactionId) public onlyOwner {
    Transaction storage transaction = transactions[_transactionId];
    require(!transaction.executed, "Transaction already executed");

    transaction.executed = true;

    if (address(this).balance < transaction.value) {
        emit ExecutionFailure(_transactionId);
        transaction.executed = false;
    } else {
        (bool success,) = transaction.to.call{value: transaction.value}("");
        if (success) {
            emit Execution(_transactionId);
        } else {
            emit ExecutionFailure(_transactionId);
            transaction.executed = false;
        }
    }
}

// Function to revoke a confirmation for a transaction
function revokeConfirmation(uint _transactionId) public onlyOwner {
    require(_transactionId < transactions.length, "Invalid transaction ID");
    Transaction storage transaction = transactions[_transactionId];
    require(transaction.isConfirmed[msg.sender], "Transaction not confirmed");
    
    transaction.isConfirmed[msg.sender] = false;
    
    emit Revocation(msg.sender, _transactionId);
}

// Function to get the contract balance
function getBalance() public view returns (uint) {
    return address(this).balance;
}
