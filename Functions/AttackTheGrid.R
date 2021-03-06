AttackTheGrid <- function(NetworkList, 
                          AttackStrategy, 
                          referenceGrid = NULL, 
                          MinMaxComp = 0.8, 
                          TotalAttackRounds=100,
                          CascadeMode = TRUE, 
                          CumulativeAttacks = NULL){
  #This function attacks the grid using a given attack strategy
  #NetworkList: A list of lists where each element of the sub list is an igraph object, the first time it is used the
    #the network list is simply list(list(g))
  #AttackStrategy: A function that calculates which node to delete the function is is in "quo" form and embedded in an
    #attack type
  #referenceGrid: the grid that will be used to test the largest component against if NULL it uses the given network
  #MinMaxComp: The minimum size of the maximum component, as a fraction, for the process to continue, the default is set to 0.8
  #TotalAttackRounds: The maximum number of nodes to be removed before the process stops
  #CascadeMode: Whether the power flow equations will be used to check line-overloading or not
  #CumulativeAttacks = The total number of attacks that have taken place so far
  
  #gets the last network in the list
  g <- NetworkList[[length(NetworkList)]]

   g <- g[[length(g)]]
  

  if(is.null(referenceGrid)){
    referenceGrid  <- g
  }

   
  #Remove the desired part of the network.
  gCasc<- AttackStrategy %>% 
    eval_tidy(., data = list(g = g)) #The capture environment contains delete nodes, however the current g is fed in here
  
  #Rebalence network
  #This means that the Cascade calc takes a balanced network which is good.
  gCasc <- BalencedGenDem(gCasc, "Demand", "Generation")
  
  

  GridCollapsed<- ecount(gCasc)==0

  gCasc <- list(gCasc)
  
  #This If statement prevents Cascading if theire are no cascadable components
  if(!GridCollapsed){
  
  if(CascadeMode){
  #this returns a list of networks each of the cascade
  gCasc <- Cascade(gCasc)
  }
  
  message(paste("Attack ",CumulativeAttacks, " Nodes Remaining", vcount(gCasc[[length(gCasc)]])))
  
  } else{
   
    message("Grid completely collapsed continuing until stop conditions met")
    
  }
  

  if(is.null(CumulativeAttacks)){
    CumulativeAttacks2 <- 1
  } else {
    CumulativeAttacks2 <- CumulativeAttacks + 1
  }


  #concatanate the new list with the list of lists
  NetworkList2 <- NetworkList
  NetworkList2[[length(NetworkList2)+1]] <-gCasc
  
  #extract the last network from the just completed cascade
  gCascLast <- gCasc[[length(gCasc)]]
    
  #If the largest componant is larger than the MinMaxComp threshold
  #call the function again and delete a new node.

  #when the grid has collapsed problems arise this helps deal with that
  MaxComp <- suppressWarnings(max(components(gCascLast)$csize))
  
  FractGC <-ifelse(is.finite(MaxComp),MaxComp/vcount(referenceGrid), 0)

    if( !(FractGC < MinMaxComp | length(NetworkList2)-1==TotalAttackRounds) ){
    NetworkList2 <- AttackTheGrid(NetworkList = NetworkList2, 
                                  AttackStrategy, 
                                  referenceGrid = referenceGrid, 
                                  MinMaxComp = MinMaxComp,
                                  TotalAttackRounds = TotalAttackRounds, 
                                  CascadeMode = CascadeMode,
                                  CumulativeAttacks = CumulativeAttacks2
                                  )
  }

  return(NetworkList2)
  
}