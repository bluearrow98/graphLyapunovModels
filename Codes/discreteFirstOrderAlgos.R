library(glasso)

# Discrete First-order Algorithm 1 Implementation
algorithm1 <- function( X, y, k, inits = 50, p = dim(X)[2], polish = T, maxIter = 1000, tol = 1e-4) {

  p <- ncol(X)
  n <- nrow(X)
  diag_ind <- seq(1, p, by = sqrt(p) + 1)

  #  The largest eigen value of (X^T*X) for step size computation
  L <- norm(t(X) %*% X, type = "2")

  # Initialize starting values
  beta0 <- mvrnorm(1, rep(0, p), 4 * diag(p))

  obj_crit <- Inf
  best_beta <- beta0
  beta <- beta0

  for (i in 1:inits) {
    for (j in 1:maxIter) {
    obj_old <- 0.5 * norm(X %*% beta - y, type = "2") ** 2

    # Gradient update
    grad <- t(X) %*% (X %*% beta - y)
    beta <- beta - grad / L

    # Project the coefficients (H_k operator)
    idx <- which(abs(beta[-diag]) %in% sort(abs(beta[-diag]), decreasing = TRUE)[1:(k - sqrt(p))])
    beta[-idx] <- 0

    # Objective at new beta
    obj <- 0.5 * norm(X %*% beta - y, type = "2") ** 2

    if (abs(obj_old - obj) <= tol) break

    obj_old <- obj

    }

    # Compare the current objective with the best achieved so far
    # and update the best beta
    if (obj < obj_crit) {
      obj_crit <- obj
      best_beta <- beta
    }

    # Initialize guess for the next step
    beta <- mvrnorm(1, rep(0, p), 4 * diag(p))
  }

  return(list("bm" = best_beta, "gm" = obj_crit))
}

# Discrete First-order Algorithm 2 Implementation
algorithm2 <- function( X, y, k, inits = 50, p = dim(X)[2], polish = T, maxIter = 1000, tol = 1e-4) {

  p <- ncol(X)
  n <- nrow(X)
  diag_ind <- seq(1, p, by = sqrt(p) + 1)

  #  The largest eigen value of (X^T*X) for step size computation
  L <- norm(t(X) %*% X, type = "2")

  # Initialize starting values
  beta0 <- mvrnorm(1, rep(0, p), 4 * diag(p))

  obj_crit <- Inf
  best_beta <- beta0
  beta <- beta0

  for (i in 1:inits) {
    eta <- beta - t(X) %*% (X %*% beta - y) / L
    idx <- which(abs(eta[-diag_ind]) %in% sort(abs(eta[-diag_ind]), decreasing = TRUE)[1:(k - sqrt(p))])
    eta[-idx] <- 0
    for (j in 1:maxIter) {

        obj_old <- 0.5 * norm(X %*% eta - y, type = "2") ** 2

        # Solve min_lambda g(lambda*eta_m + (1-lambda)*beta_m)
        lambda <- solve(t(X %*% (eta - beta)) %*% (X %*% (eta - beta)),
                        t(X %*% (eta - beta)) %*% (y - X %*% beta))
        beta <- eta %*% lambda + beta %*% (1 - lambda)

        # Gradient update to calculate eta_m+1
        eta <- beta - t(X) %*% (X %*% beta - y) / L

        # Project the coefficients (H_k operator)
        idx <- which(abs(eta[-diag_ind]) %in% sort(abs(eta[-diag_ind]), decreasing = TRUE)[1:(k - sqrt(p))])
        eta[-idx] <- 0
        
        # Perform least squares polishing, if we are asked to
        if (polish) eta[idx] <- lsfit(X[, idx],
                                        y, intercept = FALSE)$coefficients

        # Objective at new eta
        obj <- 0.5 * norm(X %*% eta - y, type = "2") ** 2

        if (abs(obj - obj_old) <= tol) break

        obj_old <- obj

    }

    # Compare the current objective with the best achieved so far
    # and update the best beta
    if (obj < obj_crit) {
      obj_crit <- obj
      best_beta <- eta
    }

    # Initialize guess for the next step
    beta <- mvrnorm(1, rep(0, p), 4 * diag(p))
  }

  return(list("bm" = best_beta, "gm" = obj_crit))
}

proj_grad <- function(X, y, k, nruns = 50, maxiter = 1000, tol = 1e-4, polish = TRUE) {

  n <- nrow(X)
  p <- ncol(X)
  diag_ind <- seq(1, p, by = sqrt(p) + 1)

  # If beta0 is NULL, use thresholded least squares coefficients when p < n,
  # and thresholded marginal regression coefficients when p >= n
  if (p < n) beta0 <- lsfit(X, y, int = FALSE)$coef
  else beta0 <- t(X) %*% y / colSums(X^2)

  ids <- order(abs(beta0[-diag_ind]), decreasing=TRUE)
  beta0[-diag_ind][-ids[1:(k - sqrt(p))]] <- 0

  # If L is NULL, use the power method to approximate the largest eigenvalue
  # of X^T X, for the step size
  L <- norm(t(X)%*%X,type = "2")

  beta.beta <- beta0
  best.crit <- Inf
  beta <- beta0

  for (r in 1:nruns) {
    for (i in 1:maxiter) {
      beta.old <- beta

      # Take gradient descent step
      grad <- -t(X) %*% (y - X %*% beta)
      beta <- beta - grad/L

      # Set to zero all but the top k
      ids <- order(abs(beta[-diag_ind]), decreasing=TRUE)
      beta[-diag_ind][-ids[1:(k - sqrt(p))]] <- 0

      # Perform least squares polishing, if we are asked to
      if (polish) beta[beta != 0] <- lsfit(X[, beta != 0], y, int = FALSE)$coef

      # Stop if the relative difference in coefficients is small enough
      if (norm(beta - beta.old) / max(norm(beta), 1) < tol) break
    }

    # Compute the criterion for the current coefficients, compare to the
    # best so far
    cur.crit <- sum((y - X %*% beta)^2)
    if (cur.crit < best.crit) {
      best.crit <- cur.crit
      best.beta <- beta
    }

    # Start the next run off at a random spot (particular choice matches
    # Rahul's Matlab code)
    beta <- beta0 + 2 * runif(p) * max(abs(beta0), 1)
  }

  obj <- 0.5*norm(X %*% best.beta - y, type = "2")**2

  return(list("bm" = best.beta, "gm" = obj))
}

proj_grad_oneEdge <- function(X, y, k, nruns = 50, maxiter = 1000, tol = 1e-4, polish = TRUE) {

  n <- nrow(X)
  p <- ncol(X)

  # If beta0 is NULL, use thresholded least squares coefficients when p < n,
  # and thresholded marginal regression coefficients when p >= n
  if (p < n) beta0 <- lsfit(X, y, int = FALSE)$coef
  else beta0 <- t(X) %*% y / colSums(X^2)

  # One edge initialization
  diag_ind <- seq(1, p, by = sqrt(p) + 1)
  beta0 <- one_edge_ini(beta0, p)

  # If L is NULL, use the power method to approximate the largest eigenvalue
  # of X^T X, for the step size
  L <- norm(t(X)%*%X,type = "2")

  beta.beta <- beta0
  best.crit <- Inf
  beta <- beta0

  for (r in 1:nruns) {
    for (i in 1:maxiter) {
      beta.old <- beta

      # Take gradient descent step
      grad <- -t(X) %*% (y - X %*% beta)
      beta <- beta - grad/L

      # Set to zero all but the top k
      ids <- order(abs(beta[-diag_ind]), decreasing=TRUE)
      beta[-diag_ind][-ids[1:(k - sqrt(p))]] <- 0

      # Perform least squares polishing, if we are asked to
      if (polish) beta[beta != 0] <- lsfit(X[, beta != 0], y, int = FALSE)$coef

      # Stop if the relative difference in coefficients is small enough
      if (norm(beta - beta.old) / max(norm(beta), 1) < tol) break
    }

    # Compute the criterion for the current coefficients, compare to the
    # best so far
    cur.crit <- sum((y - X %*% beta)^2)
    if (cur.crit < best.crit) {
      best.crit <- cur.crit
      best.beta <- beta
    }

    # Start the next run off by adding another edge randomly
    beta <- one_edge_next(beta0, diag_ind, p)
  }

  obj <- 0.5*norm(X %*% best.beta - y, type = "2")**2

  return(list("bm" = best.beta, "gm" = obj))
}

one_edge_ini <- function(beta0, p){
  # Get the diagonal indices
  diag_ind <- seq(1, p, by = sqrt(p) + 1)
  # Get non-zero non-diagonal indices
  nzero_ind <- setdiff(seq(1,p), diag_ind)
  # Sample a random index from the off-diagonal
  edge_ind <- sample(nzero_ind, 1)
  # Assign everything else as zero
  beta0[-c(diag_ind, edge_ind)] <- 0

  return(beta0)
}

one_edge_next <- function(beta0, diag_ind, p){
  # Start with random number of edges
  randEdge <- 2 * runif(p) * max(abs(beta0), 1)
  # Choose a single edge at random out of all
  edge_ind <- sample(seq(1, p)[-diag_ind], 1)
  # Add it to the initial one edge initialized vector
  beta <- beta0 + randEdge
  beta[-c(diag_ind, edge_ind)] <- 0

  return(beta)
}

proj_grad_glasso <- function(X, y, k, Sigma = getSigma(X), N, nruns = 50, maxiter = 1000, tol = 1e-4, polish = TRUE) {

  n <- nrow(X)
  p <- ncol(X)
  diag_ind <- seq(1, p, by = sqrt(p) + 1)

  # If beta0 is NULL, use thresholded least squares coefficients when p < n,
  # and thresholded marginal regression coefficients when p >= n
  if (p < n) beta0 <- lsfit(X, y, int = FALSE)$coef
  else beta0 <- t(X) %*% y / colSums(X^2)

  # Initialization by graphical lasso
  coarseglasso <- glassopath(Sigma)
  optRho <- coarseglasso$rholist[min(sapply(1:dim(coarseglasso$wi)[3], function(x){
    if (sum(coarseglasso$wi[, , x] != 0) == sqrt(p)) return(x) else return(100) # just some high value
  }))]
  graphLasso <- foreach(i = seq(optRho/10, optRho, length.out = 100)) %dopar% {
    glasso(s = Sigma, rho = i)
  }
  bicScores <-sapply(graphLasso, function(x) {
    bic_score(x$wi, Sigma,N)
  })
  posterior_prob <- postprb(bicScores)
  bestgLasso <- which.max(posterior_prob)
  beta0[c(graphLasso[[bestgLasso]]$wi) == 0] <- 0

  ids <- order(abs(beta0[-diag_ind]), decreasing = TRUE)
  beta0[-diag_ind][-ids[1:(k - sqrt(p))]] <- 0

  # If L is NULL, use the power method to approximate the largest eigenvalue
  # of X^T X, for the step size
  L <- norm(t(X)%*%X,type = "2")

  beta.beta <- beta0
  best.crit <- Inf
  beta <- beta0

  for (r in 1:nruns) {
    for (i in 1:maxiter) {
      beta.old <- beta

      # Take gradient descent step
      grad <- -t(X) %*% (y - X %*% beta)
      beta <- beta - grad/L

      # Set to zero all but the top k
      ids <- order(abs(beta[-diag_ind]), decreasing=TRUE)
      beta[-diag_ind][-ids[1:(k - sqrt(p))]] <- 0

      # Perform least squares polishing, if we are asked to
      if (polish) beta[beta != 0] <- lsfit(X[,beta != 0], y, int = FALSE)$coef

      # Stop if the relative difference in coefficients is small enough
      if (norm(beta - beta.old) / max(norm(beta), 1) < tol) break
    }

    # Compute the criterion for the current coefficients, compare to the
    # best so far
    cur.crit <- sum((y - X %*% beta)^2)
    if (cur.crit < best.crit) {
      best.crit <- cur.crit
      best.beta <- beta
    }

    # Start the next run off at a random spot (particular choice matches
    # Rahul's Matlab code)
    beta <- beta0 + 2 * runif(p) * max(abs(beta0), 1)
    beta[c(graphLasso$wi[, , bestgLasso]) == 0] <- 0
  }

  obj <- 0.5 * norm(X %*% best.beta - y, type = "2") ** 2

  return(list("bm" = best.beta, "gm" = obj))
}

getSigma <- function(ASigma){

  p <- dim(ASigma)[1]

  # Retrieve diagonal elements of Sample covariance matrix
  diagInd <- seq(1, p, by = sqrt(p) + 1)
  diagElements <- sapply(diagInd, function(x, ASigma){return(ASigma[x,x] / 2)}, ASigma)

  # Retrieve the entire Sample covariance matrix
  Sigma <- ASigma[1:sqrt(p), seq(1, p, by = sqrt(p))]
  diag(Sigma) <- diagElements
  Sigma[1, 2:sqrt(p)] <- Sigma[1, 2:sqrt(p)] / 2

  return(Sigma)
  }

  applyLasso <- function(X, y, k){

    p <- sqrt(dim(X)[1])
    diag_ind <- seq(1, p ** 2, by = p + 1)

    # Lasso
    penalty <- rep(1, p ** 2)
    penalty[diag_ind] <- 0

    initGrid <- seq(10, 10^-5, length.out = 100)
    coarseLasso <- glmnet(X, y,
                        intercept = FALSE, alpha = 1,
                        standardize = FALSE, penalty.factor = penalty,
                        lambda = initGrid)

    # Find min lambda such that M is diagonal
    lambda <- min(initGrid[(colSums(penalty * (coarseLasso$beta != 0)) == 0 &
        colSums((1 - penalty) * (coarseLasso$beta != 0)) == p)])

    fineGrid <- seq(lambda, lambda / 10^4, length.out = 100)

    fineLasso <- glmnet(X, y,
                        intercept = FALSE, alpha = 1,
                        standardize = FALSE, penalty.factor = penalty,
                        lambda = fineGrid)

    # Get solution
    betas <- apply(fineLasso$beta, 2, function(x){
      ids <- order(abs(x[-diag_ind]), decreasing=TRUE)
      x[-diag_ind][-ids[1:(k - p)]] <- 0
      return(x)
    })

    # Get objective values, if necessary
    objvals <- apply(betas, 2, function(z){
            norm(X %*% z - y, type = "2")})

    best.beta <- betas[, which.min(objvals)]

    return(list("bm" = best.beta, "gm" = min(objvals)))
  }


  applyGlasso <- function(X, y, k, Sigma = getSigma(X), N){

    p <- sqrt(dim(X)[1])

    diag_ind <- seq(1, p ** 2, by = p + 1)

    # Initialization by graphical lasso
    coarseglasso <- glassopath(Sigma)
    optRho <- coarseglasso$rholist[min(sapply(1:dim(coarseglasso$wi)[3], function(x){
      if (sum(coarseglasso$wi[, , x] != 0) == p) return(x) else return(100) # just some high value
    }))]
    graphLasso <- glassopath(Sigma, rholist = seq(0, optRho, length.out = 100))
    bicScores <-apply(graphLasso$wi, 3, bic_score, Sigma, N)
    posterior_prob <- postprb(bicScores)
    bestgLasso <- which.max(posterior_prob)

    glassoSigma <- graphLasso$w[, , bestgLasso]

    KPermute <- spMatrix(nrow = p ** 2, ncol = p ** 2, i = c(seq(1, p ** 2)),
                        j = c(sapply(seq(1, p),
                              function(x) {seq(x, p ** 2, by = p)})),
                        x = c(rep(1, p ** 2)))
    # Data matrix for regression
    X_comp <- as.matrix(kronecker(glassoSigma, diag(p)) +
                        kronecker(diag(p), glassoSigma) %*% KPermute)

    beta <- ginv(X_comp) %*% y
    ids <- order(abs(beta[-diag_ind]), decreasing=TRUE)
    beta[-diag_ind][-ids[1:(k - p)]] <- 0

    # thresholded marginal regression coefficients
    beta0 <- t(X) %*% y / colSums(X^2)

    beta0[beta == 0] <- 0
    best.beta <- beta0

    obj <- norm(X %*% beta - y, type = "2")

    return(list("bm" = best.beta, "gm" = obj))
  }