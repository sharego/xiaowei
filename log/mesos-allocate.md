

## 参考资料

1. [算法逻辑参考](http://www.cnblogs.com/popsuper1982/p/5701505.html)
2. [论文](https://people.eecs.berkeley.edu/~alig/papers/mesos.pdf)
3. [mesos 与 borg 对比](http://dongxicheng.org/mapreduce-nextgen/yarn-mesos-borg/)

## 源码 
**按版本1.7.0**

allocator 模块:
https://github.com/apache/mesos/tree/1.7.0/src/master/allocator
# 根据配置创建资源分配策略: HierarchicalDRFAllocator 或 HierarchicalRandomAllocator

若HierarchicalDRF：
https://github.com/apache/mesos/blob/1.7.0/src/master/allocator/mesos/hierarchical.hpp
https://github.com/apache/mesos/blob/1.7.0/src/master/allocator/mesos/hierarchical.cpp

初始化实例时 role 排序器 和 framework 排序器 都采用 drf 算法

allocate 声明:
https://github.com/apache/mesos/blob/1.7.0/src/master/allocator/mesos/hierarchical.hpp#L242

资源分配实现方法 __allocate()
https://github.com/apache/mesos/blob/1.7.0/src/master/allocator/mesos/hierarchical.cpp#L1575
