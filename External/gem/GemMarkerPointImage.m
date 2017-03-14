classdef GemMarkerPointImage < CoreBaseClass
    % GemMarkerPointImage. Part of the gui for the Pulmonary Toolkit.
    %
    %     You should not use this class within your own code. It is intended to
    %     be used internally within the gui of the Pulmonary Toolkit.
    %
    %     GemMarkerPointImage stores the underlying image which represents marker
    %     points. It abstracts the storage of the marker image away from the
    %     interactive creation and use of marker points in the MimViewerPanel.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. https://github.com/tomdoel/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    events
        MarkerImageHasChanged
    end
    
    properties (Access = private)
        Image           % The PTKImage object containing the image volume
    end
    
    methods
        function obj = GemMarkerPointImage()
            % The image object must be created here, not in the properties section, to
            % prevent Matlab creating a circular dependency (see Matlab solution 1-6K9BQ7)
            % Also note that theis will trigger the above pointer change callback, which
            % will set up the pixel data change callback
            obj.Image = PTKImage();            
        end
        
        function ClearMarkers(obj)
            obj.Image.Reset;
            obj.NotifyMarkerImageChanged();
        end
        
        function image_to_save = GetImageToSave(obj)
            image_to_save = obj.Image;
        end
        
        function [slice_markers, slice_size] = GetMarkersFromImage(obj, slice_number, dimension)
            slice = obj.GetSlice(slice_number, dimension);
            slice_size = size(slice);
            
            [y, x] = find(slice);
            slice_markers = [];
            for index = 1 : numel(y)
                next_marker = [];
                next_marker.x = x(index);
                next_marker.y = y(index);
                next_marker.colour = slice(y(index), x(index));
                slice_markers{end + 1} = next_marker;
            end
        end
        
        function global_coords = LocalToGlobalCoordinates(obj, local_coords)
            global_coords = obj.Image.LocalToGlobalCoordinates(local_coords);
        end
        
        function ChangeMarkerPoint(obj, local_coords, colour)
            global_coords = obj.Image.LocalToGlobalCoordinates(local_coords);
            global_coords = obj.BoundCoordsInImage(obj.Image, global_coords);

            current_value = obj.Image.GetVoxel(global_coords);
            if (current_value ~= colour)
                obj.Image.SetVoxelToThis(global_coords, colour);
                obj.NotifyMarkerImageChanged();
            end
        end
        
        function ChangeMarkerSubImage(obj, new_image)
            obj.Image.ChangeSubImage(new_image);
            obj.NotifyMarkerImageChanged();
        end
        
        function BackgroundImageChanged(obj, template)
%             obj.SetBlankMarkerImage(template); % ToDo: resize marker image
        end
        
        function SetBlankMarkerImage(obj, template)
            obj.Image = template.BlankCopy();
            obj.Image.ChangeRawImage(zeros(template.ImageSize, 'uint8'));
            obj.Image.ImageType = PTKImageType.Colormap;
            obj.NotifyMarkerImageChanged();
        end
        
        function ForceMarkerImageCreation(obj, template)
            if ~obj.Image.ImageExists()
                obj.SetBlankMarkerImage(template);
            end
        end
        
        function index_of_nearest_marker = GetIndexOfPreviousMarker(obj, current_coordinate, maximum_skip, orientation)
            
            coordinate_range = [current_coordinate - maximum_skip, current_coordinate - 1];
            coordinate_range = max(1, coordinate_range);
            coordinate_range = coordinate_range(1) : coordinate_range(2);
            
            switch orientation
                case GemImageOrientation.XZ
                    consider_image = obj.Image.RawImage(coordinate_range, :, :);
                case GemImageOrientation.YZ
                    consider_image = obj.Image.RawImage(:, coordinate_range, :);
                case GemImageOrientation.XY
                    consider_image = obj.Image.RawImage(:, :, coordinate_range);
            end
            other_dimension = setxor([1 2 3], orientation);
            any_markers = any(any(consider_image, other_dimension(1)), other_dimension(2));
            any_markers = squeeze(any_markers);
            any_markers = any_markers(end:-1:1);
            index_of_nearest_marker = find(any_markers, 1, 'first');
            if isempty(index_of_nearest_marker)
                index_of_nearest_marker = max(1, current_coordinate - maximum_skip);
            else
                index_of_nearest_marker = current_coordinate - index_of_nearest_marker;
            end    
        end
        
        function index_of_nearest_marker = GetIndexOfNextMarker(obj, current_coordinate, maximum_skip, orientation)
            max_coordinate = obj.Image.ImageSize(orientation);
            coordinate_range = [current_coordinate + 1, current_coordinate + maximum_skip, current_coordinate];
            coordinate_range = min(max_coordinate, coordinate_range);
            coordinate_range = coordinate_range(1) : coordinate_range(2);
            switch orientation
                case GemImageOrientation.XZ
                    consider_image = obj.Image.RawImage(coordinate_range, :, :);
                case GemImageOrientation.YZ
                    consider_image = obj.Image.RawImage(:, coordinate_range, :);
                case GemImageOrientation.XY
                    consider_image = obj.Image.RawImage(:, :, coordinate_range);
            end
            other_dimension = setxor([1 2 3], orientation);
            any_markers = any(any(consider_image, other_dimension(1)), other_dimension(2));
            any_markers = squeeze(any_markers);
            index_of_nearest_marker = find(any_markers, 1, 'first');
            if isempty(index_of_nearest_marker)
                index_of_nearest_marker = min(max_coordinate, current_coordinate + maximum_skip);
            else
                index_of_nearest_marker = current_coordinate + index_of_nearest_marker;
            end
        end
        
        function index_of_nearest_marker = GetIndexOfNearestMarker(obj, current_coordinate, orientation)
            consider_image = obj.Image.RawImage;
            other_dimension = setxor([1 2 3], orientation);
            any_markers = any(any(consider_image, other_dimension(1)), other_dimension(2));
            any_markers = squeeze(any_markers);
            indices = find(any_markers);
            if isempty(indices)
                index_of_nearest_marker = 1;
            else
                relative_indices = indices - current_coordinate;
                [~, min_relative_index] = min(abs(relative_indices - 0.1));
                index_of_nearest_marker = relative_indices(min_relative_index) + current_coordinate;
            end
        end

        function index_of_nearest_marker = GetIndexOfFirstMarker(obj, orientation)
            consider_image = obj.Image.RawImage;
            other_dimension = setxor([1 2 3], orientation);
            any_markers = any(any(consider_image, other_dimension(1)), other_dimension(2));
            any_markers = squeeze(any_markers);
            indices = find(any_markers);
            if isempty(indices)
                index_of_nearest_marker = 1;
            else
                [~, index_of_nearest_marker] = min(indices);
                index_of_nearest_marker = indices(index_of_nearest_marker);
            end
        end
        
        function index_of_nearest_marker = GetIndexOfLastMarker(obj, orientation)
            consider_image = obj.Image.RawImage;
            max_coordinate = obj.Image.ImageSize(orientation);
            other_dimension = setxor([1 2 3], orientation);
            any_markers = any(any(consider_image, other_dimension(1)), other_dimension(2));
            any_markers = squeeze(any_markers);
            indices = find(any_markers);
            if isempty(indices)
                index_of_nearest_marker = max_coordinate;
            else
                [~, index_of_nearest_marker] = max(indices);
                index_of_nearest_marker = indices(index_of_nearest_marker);
            end
        end
        
        function image_exists = MarkerImageExists(obj)
            image_exists = obj.Image.ImageExists;
        end        
    end
    
    methods (Access = private)
        
        function slice = GetSlice(obj, slice_number, dimension)
            slice = obj.Image.GetSlice(slice_number, dimension);
            if (dimension == 1) || (dimension == 2)
                slice = slice'; 
            end
        end
        
        function global_coords = BoundCoordsInImage(~, marker_image, global_coords)
            local_coords = marker_image.GlobalToLocalCoordinates(global_coords);

            local_coords = max(1, local_coords);
            image_size = marker_image.ImageSize;
            local_coords(1) = min(local_coords(1), image_size(1));
            local_coords(2) = min(local_coords(2), image_size(2));
            local_coords(3) = min(local_coords(3), image_size(3));

            global_coords = marker_image.LocalToGlobalCoordinates(local_coords);
        end
        
        function NotifyMarkerImageChanged(obj)
            notify(obj, 'MarkerImageHasChanged');
        end
    end
end

