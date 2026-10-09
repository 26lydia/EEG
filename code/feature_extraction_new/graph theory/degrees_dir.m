function [id,od,deg] = degrees_dir(CIJ)
%DEGREES_DIR        Indegree and outdegree
%
%   [id,od,deg] = degrees_dir(CIJ);
%
%   Node degree is the number of links connected to the node. The indegree 
%   is the number of inward links and the outdegree is the number of 
%   outward links.
%
%   Input:      CIJ,    directed (binary/weighted) connection matrix
%
%   Output:     id,     node indegree
%               od,     node outdegree
%               deg,    node degree (indegree + outdegree)
%
%   Notes:  Inputs are assumed to be on the columns of the CIJ matrix.
%           Weight information is discarded.
%
%
%   Olaf Sporns, Indiana University, 2002/2006/2008

% 1. 正值部分：行→列
CIJ_pos = double(CIJ > 0);

% 2. 负值部分：列→行
CIJ_neg = double(CIJ < 0);   % 先二值化
CIJ_neg = CIJ_neg';          % 转置，把方向改为行→列

% 3. 合并
CIJ_bin = CIJ_pos + CIJ_neg;

% ensure CIJ is binary...
CIJ_bin = double(CIJ_bin~=0);

% compute degrees
id = sum(CIJ_bin,1);    % indegree = column sum of CIJ
od = sum(CIJ_bin,2)';   % outdegree = row sum of CIJ
deg = id+od;        % degree = indegree+outdegree


