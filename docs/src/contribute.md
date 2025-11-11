# [Contribute to `TimeStruct`](@id con)

Contributing to `TimeStruct` can be achieved in several different ways.

## [File a bug report](@id con-bug_rep)

One approach to contributing to `TimeStruct` is by filing a bug report as an *[issue](https://github.com/sintefore/TimeStruct.jl/issues/new)* when unexpected behavior is occurring.

When filing a bug report, please follow these guidelines:

1. Be certain that the bug is a bug and originates in `TimeStruct`:
    - If the problem is within the results of your optimization problem, please be certain that your optimization model is correctly set up.
    - If the problem only appears for specific solvers, it is most likely not a bug in `TimeStruct`, but instead a problem with the solver wrapper for `MathOptInterface`.
      In this case, please contact the developers of the corresponding solver wrapper.
2. Label the issue as a bug, and
3. Provide a minimum working example of a case in which the bug occurs.
   This minimum working example _**should not**_ be based on a potential application of `TimeStruct`.
   Instead, it is important to focus purely on how `TimeStruct` behaves when the bug occurs.

## [Feature requests](@id con-feat_req)

Although `TimeStruct` was designed with the aim of flexibility with respect to incorporating different time structures, it sometimes still requires additional features.
Feature requests can be achieved through two approaches:

1. Create an issue describing the aim of the feature request, and
2. Incorporate the feature request through a fork of the repository and open a pull request.

### [Create an Issue](@id con-feat_req-issue)

Creating a new *[issue](https://github.com/sintefore/TimeStruct.jl/issues/new)* for a feature request is our standard approach for contributing to `TimeStruct`.
Due to the modularity of `TimeStruct`'s individual time structures, it is not necessarily straightforward to understand how to best incorporate required features into the framework without breaking existing time structures.

When creating a new issue as a feature request, please follow these guidelines:

1. **Reason for the feature**: Please describe the reasoning for the feature request. What functionality do you require in `TimeStruct`?
2. **Required outcome**: What should be the outcome when including the feature and what should be the minimum requirements of the outcome?
3. **Potential solutions**: Describe alternatives you consider. This step is not necessarily required, but can be helpful for identifying potential solutions.

### [Incorporating the feature requests through a fork](@id con-feat_req-fork)

!!! note
    The approach used for providing code is based on the excellent description from the [JuMP](https://jump.dev/JuMP.jl/stable/developers/contributing/#Contribute-code-to-JuMP) package.
    We essentially follow the same approach with minor changes.

If you would like to work directly in `TimeStruct`, you can also incorporate your changes directly.
In this case, it is beneficial to follow these outlined steps:

#### [Step 1: Create an issue](@id con-feat_req-fork-step_1)

Even if you plan to incorporate the code directly, we advise you to first follow the steps outlined in *[Create an Issue](@ref con-feat_req-issue)*.
This way, it is possible for us to comment on the solution approach(es) and assess potential problems with other time structures.

By creating an issue first, it is possible for us to comment directly on the proposed changes and assess whether we consider the proposed changes to follow the philosophy of the framework.

#### [Step 2: Create a fork of `TimeStruct`](@id con-feat_req-fork-step_2)

Contributing code to `TimeStruct` should follow the standard approach by creating a fork of the repository.
All work on the code should occur within the fork.

#### [Step 3: Checkout a new branch in your local fork](@id con-feat_req-fork-step_3)

It is in general preferable to work on a separate branch when developing new components.

#### [Step 4: Make changes to the code base](@id con-feat_req-fork-step_4)

Incorporate your changes in your new branch.
The changes should be commented to understand the thought process behind them.
In addition, please provide new tests for the added functionality and be certain that the existing tests run.
New tests should be based on a minimum working example in which the new concept is evaluated.

!!! tip
    It is in our experience easiest to use the package [`TestEnv`](https://github.com/JuliaTesting/TestEnv.jl) for testing the complete package.

Aside from the individual tests, it is required to use [`JuliaFormatter`](https://domluna.github.io/JuliaFormatter.jl/stable/) on the code.

It is not necessary to provide changes directly in the documentation.
It can be easier to include these changes after the pull request is accepted in principle.

#### [Step 5: Create a pull request](@id con-feat_req-fork-step_5)

Once you are satisfied with your changes, create a pull request towards the main branch of the `TimeStruct` repository.
We will internally assign the relevant person to the pull request.

You may receive quite a few comments with respect to the incorporation and how it may potentially affect other parts of the code.
Please remain patient as it may take potentially some time before we can respond to the changes, although we try to answer as fast as possible.
