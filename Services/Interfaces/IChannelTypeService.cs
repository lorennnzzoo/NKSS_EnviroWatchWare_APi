using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IChannelTypeService
    {
        IEnumerable<ChannelType> GetAllChannelTypes();
        ChannelType GetChannelTypeById(int id);
        void CreateChannelType(Post.ChannelType channelType);
        void UpdateChannelType(ChannelType channelType);
        void DeleteChannelType(int id);
    }
}
