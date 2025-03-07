// RUN: %clang_cc1 -triple spir -cl-std=cl2.0 -disable-llvm-passes -fdeclare-opencl-builtins -finclude-default-header %s -emit-llvm-bc -o %t.bc
// TODO: currently max version is limited to 1.1 for this test. Issues here
// that the SPIR-V module generated for blocks is invalid for versions starting
// from 1.4, spirv-val is failing with:
//   error: line 63: Interface variable id <13> is used by entry point
//                   'block_kernel' id <24>, but is not listed as an interface
//   %__block_literal_global = OpVariable %_ptr_CrossWorkgroup__struct_10
//                         CrossWorkgroup %11
// details can be found in:
// – Public issue #35: OpEntryPoint must list all global variables in the
//   interface. Additionally, duplication in the list is not allowed.
// RUN: llvm-spirv --spirv-max-version=1.1 %t.bc -spirv-text -o %t.spv.txt
// RUN: FileCheck < %t.spv.txt %s --check-prefix=CHECK-SPIRV
// RUN: llvm-spirv --spirv-max-version=1.1 %t.bc -o %t.spv
// RUN: spirv-val %t.spv
// RUN: llvm-spirv -r %t.spv -o %t.rev.bc
// RUN: llvm-dis %t.rev.bc
// RUN: FileCheck < %t.rev.ll %s --check-prefix=CHECK-LLVM

kernel void block_ret_struct(__global int* res)
{
  struct A {
      int a;
  };
  struct A (^kernelBlock)(struct A) = ^struct A(struct A a)
  {
    a.a = 6;
    return a;
  };
  size_t tid = get_global_id(0);
  res[tid] = -1;
  struct A aa;
  aa.a = 5;
  res[tid] = kernelBlock(aa).a - 6;
}

// CHECK-SPIRV: Name [[BlockInv:[0-9]+]] "__block_ret_struct_block_invoke"

// CHECK-SPIRV: 4 TypeInt [[IntTy:[0-9]+]] 32
// CHECK-SPIRV: 4 TypeInt [[Int8Ty:[0-9]+]] 8
// CHECK-SPIRV: 4 TypePointer [[Int8Ptr:[0-9]+]] 8 [[Int8Ty]]
// CHECK-SPIRV: 3 TypeStruct [[StructTy:[0-9]+]] [[IntTy]]
// CHECK-SPIRV: 4 TypePointer [[StructPtrTy:[0-9]+]] 7 [[StructTy]]

// CHECK-SPIRV: 4 Variable [[StructPtrTy]] [[StructArg:[0-9]+]] 7
// CHECK-SPIRV: 4 Variable [[StructPtrTy]] [[StructRet:[0-9]+]] 7
// CHECK-SPIRV: 4 PtrCastToGeneric [[Int8Ptr]] [[BlockLit:[0-9]+]] {{[0-9]+}}
// CHECK-SPIRV: 7 FunctionCall {{[0-9]+}} {{[0-9]+}} [[BlockInv]] [[StructRet]] [[BlockLit]] [[StructArg]]

// CHECK-LLVM: %[[StructA:.*]] = type { i32 }
// CHECK-LLVM: call {{.*}} void @__block_ret_struct_block_invoke(%[[StructA]]*
