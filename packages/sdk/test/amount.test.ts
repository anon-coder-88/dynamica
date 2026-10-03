import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {parseAssetAmount} from '../src/index.ts';
test('asset units preserve exact six and eighteen decimal inputs',()=>{
  assert.equal(parseAssetAmount('1.000001',6),1000001n);
  assert.equal(parseAssetAmount('0.000000000000000001',18),1n);
  assert.equal(parseAssetAmount('42',0),42n);
});
test('rejects excess precision, zero, signs, exponent, malformed values and overflow',()=>{
  for(const value of ['0','-1','+1','1e18','01','1.','NaN','Infinity','1.0000001'])
    assert.throws(()=>parseAssetAmount(value,6));
  assert.throws(()=>parseAssetAmount((2n**256n).toString(),0));
  assert.throws(()=>parseAssetAmount('1',-1));
  assert.throws(()=>parseAssetAmount('1',78));
});
test('uint256 maximum and smallest supported decimal unit are exact',()=>{
  assert.equal(parseAssetAmount((2n**256n-1n).toString(),0),2n**256n-1n);
  assert.equal(parseAssetAmount('0.'+'0'.repeat(76)+'1',77),1n);
});
