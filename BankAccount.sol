pragma solidity >=0.4.22 <=0.8.19;

contract BankAccount {
    event Deposit(
        address indexed user,
        uint256 indexed accountID,
        int256 value,
        uint256 timestamp
    );
    event WithdrawRequested(
        address indexed user,
        uint256 indexed accountID,
        uint256 indexed withdrawID,
        uint256 amount,
        uint256 timestamp
    );

    event Withdraw(uint256 indexed withdrawID, uint256 timestamp);
    event AccountCreated(
        address[] owners,
        uint256 indexed id,
        uint256 timestamp
    );

    struct WithdrawRequest {
        address user;
        uint256 amount;
        uint256 approvals;
        mapping(address => bool) ownersApproved;
        bool approved;
    }

    struct Account {
        address[] owners;
        uint256 balance;
        mapping(uint256 => WithdrawRequest) WtihdrawRequests;
    }

    mapping(uint256 => Account) accounts;
    mapping(address => uint256[]) userAccount;

    uint256 nextAccountID;
    uint256 nextWithdrawID;

    modifier accountOwner(uint256 accountId) {
        bool isOwner;
        for (uint256 idx; idx < accounts[accountId].owners.length; idx) {
            if (accounts[accountId].owners[idx] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "You are not an owner of this account");
        _;
    }

    modifier validOwners(address[] calldata owners) {
        require(owners.length + 1 <= 4, "maxium of 4 owners per account");
        for (uint256 i; i < owners.length; i++) {
            for (uint256 j = i + 1; j < owners.length; j++) {
                if (owners[i] == owners[j]) revert("no duplicate owners");
            }
        }
        _;
    }

    modifier sufficientBalance(uint256 accountId, uint256 amount) {
        require(accounts[accountId].balance >= amount, "insufficient balance");
        _;
    }

    modifier canApprove(uint256 accountID, uint256 withdrawId) {
        require(
            !accounts[accountID].WtihdrawRequests[withdrawId].approved,
            "this request is already approved"
        );
        require(
            accounts[accountID].WtihdrawRequests[withdrawId].user != msg.sender,
            "you cannot apporve this request"
        );
        require(
            accounts[accountID].WtihdrawRequests[withdrawId].user != address(0),
            "this request does not exist"
        );
        require(
            accounts[accountID].WtihdrawRequests[withdrawId].ownersApproved[
                msg.sender
            ],
            "you have already apporved this request"
        );
        _;
    }

    modifier canWithdraw(uint256 accountID, uint256 withdrawID) {
        require(
            accounts[accountID].WtihdrawRequests[withdrawID].user == msg.sender,
            "you did not create this request"
        );
        require(
            accounts[accountID].WtihdrawRequests[withdrawID].approved,
            "this request is not approved"
        );
        _;
    }

    function depost(uint256 accountID)
        external
        payable
        accountOwner(accountID)
    {
        accounts[accountID].balance += msg.value;
    }

    function createAccount(address[] calldata otherOwners)
        external
        validOwners(otherOwners)
    {
        address[] memory owners = new address[](otherOwners.length + 1);
        owners[otherOwners.length] = msg.sender;

        uint256 id = nextAccountID;
        for (uint256 idx; idx < owners.length; idx++) {
            if (idx < owners.length - 1) {
                owners[idx] = otherOwners[idx];
            }

            if (userAccount[owners[idx]].length > 2) {
                revert("each user can have a max of 3 accounts");
            }
            userAccount[owners[idx]].push(id);
        }

        accounts[id].owners = owners;
        nextAccountID++;
        emit AccountCreated(owners, id, block.timestamp);
    }

    function requestWithdraw(uint256 accountID, uint256 amount)
        external
        accountOwner(accountID)
        sufficientBalance(accountID, amount)
    {
        uint256 id = nextWithdrawID;
        WithdrawRequest storage request = accounts[accountID].WtihdrawRequests[
            id
        ];
        request.user = msg.sender;
        request.amount = amount;
        nextWithdrawID++;
        emit WithdrawRequested(
            msg.sender,
            accountID,
            id,
            amount,
            block.timestamp
        );
    }

    function approvalWithdraw(uint256 accountID, uint256 withdrawID)
        external
        accountOwner(accountID)
        canApprove(accountID, withdrawID)
    {
        WithdrawRequest storage request = accounts[accountID].WtihdrawRequests[
            withdrawID
        ];
        request.approvals++;
        request.ownersApproved[msg.sender] = true;

        if (request.approvals == accounts[accountID].owners.length - 1) {
            request.approved = true;
        }
    }

    function withdraw(uint256 accountID, uint256 withdrawID)
        external
        canWithdraw(accountID, withdrawID)
    {
        uint256 amount = accounts[accountID]
            .WtihdrawRequests[withdrawID]
            .amount;
        require(accounts[accountID].balance >= amount, "insufficient balance");

        accounts[accountID].balance -= amount;
        delete accounts[accountID].WtihdrawRequests[withdrawID];

        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent);

        emit Withdraw(withdrawID, block.timestamp);
    }

    function getBalance(uint256 accountID) public view returns (uint256) {
        return accounts[accountID].balance;
    }

    function getOwners(uint256 accountID)
        public
        view
        returns (address[] memory)
    {
        return accounts[accountID].owners;
    }

    function getApprovals(uint256 accountID, uint256 withdrawID)
        public
        view
        returns (uint256)
    {
        accounts[accountID].WtihdrawRequests[withdrawID].approvals;
    }

    function getAccounts() public view returns (uint256[] memory) {
        return userAccount[msg.sender];
    }
}
