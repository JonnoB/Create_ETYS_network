#Load Tariff aka generation data
setwd(Tariff)

GenerationData <- read_excel("Tariff & Transport Model_2018_19 Tariffs_External.xlsm", sheet =10, skip = 33) %>%
  setNames(make.names(names(.))) %>%
  mutate(Site = str_sub(Node.1,1,4))

LocalAssetData <- read_excel("Tariff & Transport Model_2018_19 Tariffs_External.xlsm", sheet =11, skip = 11) %>%
  setNames(make.names(names(.)))

TransportData <- read_excel("Tariff & Transport Model_2018_19 Tariffs_External.xlsm", sheet =12, skip = 11) %>%
  setNames(make.names(names(.)))

#Clean and organise the data
trans1 <-TransportData[,1:16] %>% 
  filter(!is.na(Bus.ID))

trans2 <- TransportData[,17:59] %>% 
  filter(!is.na(Bus.1)) %>%
  group_by(Bus.1, Bus.2) %>% #trying to stop the non-unique identifier problem
  mutate(Link = paste(Bus.1,Bus.2, 1:n(),sep = "-")) %>% #This allows multiple edges 
  #between the same node pair, it is not certain the data is always correct!
  ungroup %>%
  #set construct line limits really high
  mutate(Link.Type = tolower(Link.Type),
         Link.Limit = ifelse(Link.Type == "construct", 1e5, Link.Limit)) %>%
  #add in susceptance
  mutate(Y = 1/X..Peak.Security.) 

rm(TransportData)

##Create gbase
#This code block creates the line voltage attribute using the vertex meta data
VertexMetaData <- trans1 %>%
  select(Bus.Name, 
         Voltage, 
         Demand, 
         Generation = Generation.B.....Year.Round...Transport.Model., 
         BalencedPower = BusTransferB, 
         Bus.Order)

gbase <- trans2 %>%
  #"KEIT20-KINT20-1" takes 229 on am more or less arbirary basis, it is a value higher than 203 and 
  #  there are a relatively large number with that limit. The remaining 3 lines take the voltage median
  mutate(Link.Limit = case_when(
    Link == "BRAC20-BONB20-1" ~910,
    Link == "FAUG10-LAGG1Q-1" ~229,
    Link == "KEIT20-KINT20-1" ~910,
    Link == "LAGG1Q-MILW1S-1" ~132,
    TRUE ~ Link.Limit
  )) %>%
  select(Bus.1, 
         Bus.2, 
         Y, 
         Link.Limit,
         Link) %>%
  mutate(PowerFlow = 0) %>%
  graph_from_data_frame(., directed=FALSE, vertices = VertexMetaData)

gbase <- set.vertex.attribute(gbase, "component", value = components(gbase)$membership)
#deal with multiple links between the same nodes, it has to be done using Igraph
#as otherwise the order of the nodes isn't correct
gbase <- set.edge.attribute(graph = gbase, name = "Link", 
                            value = get.edgelist(gbase) %>%
                              as.tibble %>%
                              group_by(V1, V2) %>% #trying to stop the non-unique identifier problem
                              mutate(Link = paste(V1, V2, 1:n(),sep = "-")) %>% #This allows multiple edges 
                              ungroup %>% .$Link
)
gbase <- set.edge.attribute(gbase, "name", value = get.edge.attribute(gbase, "Link")) %>%
  set.edge.attribute(., "weight", value = get.edge.attribute(gbase, "Link.Limit"))


#If the voltage of the from node is equal to the voltage of the two node then the line voltage is also the same, otherwise the line is a transformer and the voltage is 0
EdgeVoltage <- ifelse(
  get.vertex.attribute(gbase, "Voltage", get.edgelist(gbase)[,1])== get.vertex.attribute(gbase, "Voltage", get.edgelist(gbase)[,2]), 
  get.vertex.attribute(gbase, "Voltage", get.edgelist(gbase)[,1]),
  0)

gbase <- set_edge_attr(gbase, "Voltage", value = EdgeVoltage)

