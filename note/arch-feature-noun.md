1. Antifragility -- 反脆弱性

    The concept of antifragility was introduced in Nassim Taleb’s book
    Antifragile (Random House). If fragility is the quality of a system
    that gets weaker or breaks when subjected to stressors, then what is
    the opposite of that? Many would respond with the idea of robust‐
    ness or resilience—things that don’t break or get weaker when sub‐
    jected to stressors. However, Taleb introduces the opposite of fragil‐
    ity as antifragility, or the quality of a system that gets stronger when
    subjected to stressors. What systems work that way? Consider the
    human immune system, which gets stronger when exposed to
    pathogens and weaker when quarantined. Can we build architec‐
    tures that way? Adopters of cloud-native architectures have sought
    to build them. One example is the Netflix Simian Army project, with
    the famous submodule “Chaos Monkey,” which injects random fail‐
    ures into production components with the goal of identifying and
    eliminating weaknesses in the architecture. By explicitly seeking out
    weaknesses in the application architecture, injecting failures, and
    forcing their remediation, the architecture naturally converges on a
    greater degree of safety over time.

    Ref: 
    [Migrating to Cloud Native Application Architectures](http://download3.vmware.com/vmworld/2015/downloads/oreilly-cloud-native-archx.pdf)

2.  Robustness -- 鲁棒性/健壮性

3.  Flexible -- 

4.  Resilient -- 可恢复性/回弹性

    The system stays responsive in the face of failure. This applies not
    only to highly-available, mission-critical systems — any system that
    is not resilient will be unresponsive after a failure. Resilience is
    achieved by replication, containment, isolation and delegation.
    Failures are contained within each component, isolating components
    from each other and thereby ensuring that parts of the system can
    fail and recover without compromising the system as a whole. Recovery
    of each component is delegated to another (external) component and
    high-availability is ensured by replication where necessary. The
    client of a component is not burdened with handling its failures.

    Ref:
    [The Reactive Manifesto](https://www.reactivemanifesto.org/)

5.  Scalable  -- 可扩展性

6.  Reliable -- 可靠性

7.  Elastic -- 弹性

8.  Available -- 可用性

9.  Auditable -- 可审计

10.  Observable  -- 可测量

11.  Schedulable

12.  Upgradeable

13.  Measurable



