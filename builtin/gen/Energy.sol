pragma solidity ^0.4.18;
import "./Token.sol";
import './ERC223Receiver.sol';

/// @title Energy an token that represents fuel for VET.
contract Energy is Token {
    mapping(address => mapping (address => uint256)) allowed;

    function n() internal view returns(EnergyNative) {
        return EnergyNative(this);
    }
  
    function executor() public view returns(address) {
        return n().nativeGetExecutor();
    }

    ///@return ERC20 token name
    function name() public pure returns (string) {
        return "VeThor";
    }

    ///@return ERC20 token decimals
    function decimals() public pure returns (uint8) {
        return 18;    
    }

    ///@return ERC20 token symbol
    function symbol() public pure returns (string) {
        return "VTHO";
    }

    ///@return ERC20 token total supply
    function totalSupply() public constant returns (uint256) {
        return n().nativeGetTotalSupply();
    }

    function totalBurned() public constant returns(uint256) {
        return n().nativeGetTotalBurned();
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return n().nativeGetBalance(_owner);
    }

    function _transfer(address _from, address _to, uint256 _amount) internal {
        if (_amount > 0) {
            require(n().nativeSubBalance(_from, _amount));

            // believed that will never overflow
            n().nativeAddBalance(_to, _amount);
        }
    
        if (isContract(_to)) {
            // Require proper transaction handling.
            ERC223Receiver(_to).tokenFallback(_from, _amount, new bytes(0));
        }
        Transfer(_from, _to, _amount);
    }

    function transfer(address _to, uint256 _amount) public returns (bool success) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from,address _to,uint256 _amount) public returns(bool success) {
        require(allowed[_from][_to] >= _amount);
        allowed[_from][_to] -= _amount;

        _transfer(_from, _to, _amount);        
        return true;
    }

    function allowance(address _owner, address _spender)  public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function approve(address _reciever, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_reciever] = _amount;
        Approval(msg.sender, _reciever, _amount);
        return true;
    }

    /// @notice the contract owner approves `_contractAddr` to transfer `_amount` tokens to `_to`
    /// @param _contractAddr The address of the contract able to transfer the tokens
    /// @param _to who receive the `_amount` tokens
    /// @param _amount The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function transferFromContract(address _contractAddr, address _to, uint256 _amount) public returns (bool success) {
        require(msg.sender == n().nativeGetContractMaster(_contractAddr));        
        _transfer(_contractAddr, _to, _amount);
        return true;
    }  
    
    function approveConsumption(address _contractAddr, address _caller,uint256 _credit,uint256 _recoveryRate,uint64 _expiration) public {
        // the origin can be contract itself or master
        require(msg.sender == _contractAddr || msg.sender == n().nativeGetContractMaster(_contractAddr));

        require(isContract(_contractAddr));
        require(!isContract(_caller));

        n().nativeApproveConsumption(_contractAddr, _caller, _credit, _recoveryRate, _expiration);

        ApproveConsumption(_contractAddr, _caller, _credit, _recoveryRate, _expiration);
    }

    function consumptionAllowance(address _contractAddr, address _caller) public view returns (uint256) {
        return n().nativeGetConsumptionAllowance(_contractAddr, _caller);        
    }

    function setSupplier(address _contractAddr, address _supplier) public {
        require(msg.sender == _contractAddr || msg.sender == n().nativeGetContractMaster(_contractAddr));
        require(isContract(_contractAddr));

        n().nativeSetSupplier(_contractAddr, _supplier, false);

        SetSupplier(_contractAddr, _supplier);
    }

    function getSupplier(address _contractAddr) public view returns(address supplier, bool agreed) {
        return n().nativeGetSupplier(_contractAddr);
    }

    function agreeToBeSupplier(address _contractAddr) public {
        var (supplier, agreed) = n().nativeGetSupplier(_contractAddr);
        require(!agreed && supplier == msg.sender);

        n().nativeSetSupplier(_contractAddr, supplier, true);
        AgreeToBeSupplier(_contractAddr, supplier);
    }

    function getContractMaster(address _contractAddr) public view returns(address) {
        return n().nativeGetContractMaster(_contractAddr);
    }

    function setContractMaster(address _contractAddr, address _newMaster) public {
        address oldMaster = n().nativeGetContractMaster(_contractAddr);
        require(msg.sender == oldMaster);
        n().nativeSetContractMaster(_contractAddr, _newMaster);
        SetContractMaster(_contractAddr, oldMaster, _newMaster);
    }

    function adjustGrowthRate(uint256 rate) public {
        require(msg.sender == n().nativeGetExecutor());
        n().nativeAdjustGrowthRate(rate);

        AdjustGrowthRate(rate);
    }
    
    /// @param _addr an address of a normal account or a contract
    /// 
    /// @return whether `_addr` is a contract or not
    function isContract(address _addr) view internal returns(bool) {        
        if (_addr == 0) {
            return false;
        }
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
    
    
    event AdjustGrowthRate(uint256 rate);
    event ApproveConsumption(address indexed contractAddr, address indexed caller, uint256 credit, uint256 recoveryRate, uint64 expiration);    
    event SetSupplier(address contractAddr, address supplier);
    event AgreeToBeSupplier(address contractAddr, address supplier);
    event SetContractMaster(address indexed contractAddr, address oldMaster, address newMaster);
}

contract EnergyNative {
    function nativeGetExecutor() public view returns(address);

    function nativeGetTotalSupply() public view returns(uint256);
    function nativeGetTotalBurned() public view returns(uint256);
    
    function nativeGetBalance(address addr) public view returns(uint256);
    function nativeAddBalance(address addr, uint256 amount) public;
    function nativeSubBalance(address addr, uint256 amount) public returns(bool);

    function nativeAdjustGrowthRate(uint256 rate) public;

    function nativeApproveConsumption(address contractAddr, address caller, uint256 credit, uint256 recoveryRate, uint64 expiration) public;
    function nativeGetConsumptionAllowance(address contractAddr, address caller) public view returns(uint256);

    function nativeSetSupplier(address contractAddr, address supplier, bool agreed) public;
    function nativeGetSupplier(address contractAddr) public view returns(address supplier, bool agreed);

    function nativeSetContractMaster(address contractAddr, address master) public;
    function nativeGetContractMaster(address contractAddr) public view returns(address);
}