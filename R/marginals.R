#' Average Partial Effects of the Covariates
#' 
#' Calculate average partial effects (APE) of independent variable from a fractional multinomial logit model. 
#' 
#' @param object An "fmlogit" object.
#' @param effect Can be "marginal", for marginal effect; or "discrete", for discrete changes from
#' the min to the max. 
#' @param marg.type Type of marginal or discrete effects to be computed. Default to "atmean", the effect at 
#' the mean of all covariates. Also take "aveacr", the averaged effects across all observations. See details. 
#' @param se Whether to calculate standard errors for those margins. See details. 
#' @param varlist A string vector which provides the name of variables to calculate 
#' the marginal effect. If missing, all variables except the constant will be calculated. 
#' Use "constant" if wish to compute the marginal effect of constant. 
#' @param marg.list A list of matrices storing the marginal effect matrix for each observation. Exists 
#' only if marg.type="aveacr". 
#' @param at Specify values of the X-matrix at which the partial effect will be retrieved. Expect a vector input
#' of length K-1. Only supported for \code{marg.type="atmean"}. See \code{predict.fmlogit(newdata)}. 
#' @param R Number of times to sample for the Krinsky-Robb standard error. Default to 1000. 
#' @details This module calculates the average partial effects (APEs) from a fractional multinomial logit model.
#' Partial effects are the counterpart of the marginal effects in a linear model setting. In linear models, 
#' usually the parameter estimate itself represents marginal effect (if the variable in question is continuous). 
#' In logit models, however, the parameter estimates at hand is the effect on log-ratio between the choice variable
#' and the baseline variable. This function is intended to extract APEs from the 
#' coefficient estimates completed from the fractional multinomial logit models.
#' 
#' This function allows for two types of partial effects: marginal effect, and discrete effect.
#' Marginal effect represents how a unit change in one continuous variable x may influence the choice variable y. 
#' The estimate of marginal effect is very straighforward. However, special care is needed when averaging 
#' the marginal effect across observations to acquire APE. One approach is to use the estimate of the marginal effect while setting
#' other explanatory variables at the mean. We call this marginal effect at the mean (MEM), which corresponds
#' to the option \code{marg.type=atmean}. Another approach is to take the average of marginal effects for each
#' individual. We call this average marginal effect (AME), which corresponds to the option \code{marg.type=
#' aveacr}. 
#' 
#' The discrete effect represents how a discrete change in one specific x, discrete or continuous, influence the choice variable y. 
#' This is more useful for categorical variables, as calculating the "marginal effect" makes little sense
#' for them. In this function, we calculate the discrete effect by changing the explanatory variable from 
#' its minimum to its maximum. For a binary variable, this is just the difference between 0 and 1. Similar 
#' to the marginal effect case, we also have discrete effect at the mean (DEM), corresponding to \code{marg.type= atmean}
#'  and average dscrete effect (ADE), corresponding to \code{marg.type=aveacr}.
#' 
#' Standard error is provided for the effects by using Krinsky-Robb(KR) method. Krinsky-Robb is a simulation-based
#' method that calculates the empirical value of a function given a known distribution of its variables. Here 
#' we provide Krinsky-Robb standard error for MEM and DEM, and the user can specify how many times of 
#' simulation \code{R} should the Krinsky-Robb algorithm run. 
#' 
#' The user can also specify a subset of explanatory variables when calculating effects. This is done through
#' specifying string vectors containing the column names of the explanatory variables to \code{varlist}. As the
#' KR standard error can be time-consuming, it is advised to calculate only the variables in need. 
#' 
#' @return The function returns an object of class "fmlogit.margins". It contains the following component:
#' @return \code{effects} A matrix of calculated effects.
#' @return \code{se} A matrix of standard errors corresponding to the effects. Shows up if se=T for the 
#' input parameter.
#' @return \code{ztable} A list of matrices containing effects, standard errors, z-stats and p-values.
#' @return \code{R} Number of simulation times for Krinsky-Robb standard error calculation. Null if se=F.  
#' @return \code{expl} String message explaining the effects calculated.    
#' 
#' @examples 
#' #results1 = fmlogit(y,X)
#' effects(results1,effect="marginal")
#' effects(results1,effect="discrete",varlist = colnames(object$X)[c(1,3)])
#' @export effects.fmlogit

effects.fmlogit<-function(object,effect=c("marginal","discrete"),
                          marg.type="atmean",se=F,varlist = NULL,at=NULL,R=1000){
  j=length(object$estimates)+1; K=dim(object$estimates[[1]])[1]; N=dim(object$y)[1]
  betamat = object$coefficient
  R = R # for Krinsky-Robb sampling
  # determine variables
  Xnames = colnames(object$X); ynames = colnames(object$y)
  if(length(varlist)==0){
    varlist=Xnames[-K]
    var_colNo = c(1:(K-1))
    k = length(var_colNo)
  }else{
    var_colNo = which(Xnames %in% varlist)
    if(length(varlist) != length(var_colNo)) stop("Unrecognized varlist input. Please double check your spelling")
    k = length(var_colNo)
  }
  
  xmarg = matrix(ncol=k,nrow=j)
  se_mat = matrix(ncol=k,nrow=j)
  marg_list = list()
  
  if(effect == "marginal"){
    # calculate marginal effects
    yhat = predict(object); yhat = as.matrix(yhat)
    for(c in var_colNo){
      c1 = which(var_colNo == c)
      if(marg.type == "aveacr"){
        # this is the average marginal effect for all observations
        beta_bar = as.vector(yhat %*% betamat[,c])
        betak_long = matrix(rep(betamat[,c],N),nrow=N,byrow=T)
        marg_mat =  yhat * (betak_long-beta_bar)
        xmarg[,c1] = colMeans(marg_mat)
        marg_list[[c1]] = marg_mat
      }
      if(marg.type == "atmean"){
        # this is the marginal effect at the mean
        # mean calculation
        if(is.null(at)) at = colMeans(object$X[,-K])
        yhat_mean = predict(object,newdata=at)
        beta_bar = sum(yhat_mean * betamat[,c])
        betak = betamat[,c]
        marg_vec = yhat_mean * (betak - beta_bar)
        xmarg[,c1] = as.numeric(marg_vec) 
      }
      if(se==T){
        # se calculation, using atmean by default
        se_k = rep(0,j)
        for(i in 1:j){
          se_k[i] = sqrt(diag(object$vcov[[i]])[c])
          new_betak = rnorm(R,betamat[j,c],se_k[i])
          marg_matrix = matrix(nrow=R,ncol=j)
          for(r in 1:R){
            new_betamat = betamat; new_betamat[i,c] = new_betak[r]
            yhat_mean = predict(object,newdata=colMeans(object$X[,-K]),newbeta = new_betamat)
            beta_bar = sum(yhat_mean * new_betamat[,c])
            betak = new_betamat[,c]
            marg_vec = yhat_mean * (betak - beta_bar)
            marg_matrix[r,i] = as.numeric(marg_vec)[i]
          }
          se_mat[i,c1] = sd(marg_matrix[,i])
        }}}}
  
  if(effect=="discrete"){
    for(c in var_colNo){
      c1 = which(var_colNo == c)
      if(marg.type == "aveacr"){
        Xmin <- Xmax <- object$X[,-K]
        Xmin[,c] = min(object$X[,c])
        Xmax[,c] = max(object$X[,c])
        yhat_min = predict(object,newdata=Xmin)
        yhat_max = predict(object,newdata=Xmax)
        ydisc = yhat_max - yhat_min
        xmarg[,c1] = colMeans(ydisc)
        marg_list[[c1]] = ydisc
      }
      if(marg.type == "atmean"){
        if(is.null(at)) at = colMeans(object$X[,-K])
        Xmin <- Xmax <- at
        Xmin[c] = min(object$X[,c])
        Xmax[c] = max(object$X[,c])
        yhat_min = predict(object,newdata=Xmin)
        yhat_max = predict(object,newdata=Xmax)
        ydisc = yhat_max - yhat_min
        xmarg[,c1] = as.numeric(ydisc)
      }
      if(se==T){
        # se calculation for discrete margins. using atmean by default
        se_k = rep(0,j)
        Xmin <- Xmax <- colMeans(object$X[,-K])
        Xmin[c] = min(object$X[,c])
        Xmax[c] = max(object$X[,c])
        marg_matrix = matrix(nrow=R,ncol=j)
        for(i in 1:j){
          se_k[i] = sqrt(diag(object$vcov[[i]])[c])
          new_betak = rnorm(R,betamat[j,c],se_k[i])      
          for(r in 1:R){
            new_betamat = betamat; new_betamat[i,c] = new_betak[r]
            yhat_min = predict(object,newdata=Xmin,newbeta = new_betamat)
            yhat_max = predict(object,newdata=Xmax,newbeta = new_betamat)
            ydisc = yhat_max - yhat_min
            marg_matrix[r,i] = as.numeric(ydisc)[i]
          }
          se_mat[i,c1] = sd(marg_matrix[,i])
        }}}}
  # generating hypothesis testing tables.
  listmat = list()
  if(se){
    for(i in 1:k){
      tabout = matrix(ncol=4,nrow=j)
      tabout[,1:2] = cbind(xmarg[,i],se_mat[,i])
      tabout[,3] = tabout[,1] / tabout[,2]
      tabout[,4] = 2*(1-pnorm(abs(tabout[,3])))
      colnames(tabout) = c("estimate","std","z","p-value")
      rownames(tabout) = ynames
      listmat[[i]] = tabout
    }
    names(listmat)=varlist
  }
  
  
  colnames(xmarg) <- colnames(se_mat) <- varlist
  rownames(xmarg) <- rownames(se_mat) <-colnames(object$y)
  outlist=list()
  outlist$effects = xmarg
  if(se==T){outlist$se = se_mat; outlist$ztable = listmat}
  if(marg.type=="aveacr") {names(marg_list)=varlist; outlist$marg.list = marg_list}
  marg.type.out = ifelse(marg.type=="atmean","at the mean,","average across observations,")

  # please include this in the file
  outlist$R = ifelse(se,R,0)
  # please

  outlist$expl = paste(effect,"effect",marg.type.out,
                       ifelse(se==T,"Krinsky-Robb standard error calculated","standard error not computed"))
  return(structure(outlist,class="fmlogit.margins"))
}
