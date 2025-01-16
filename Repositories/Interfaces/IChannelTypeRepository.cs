using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IChannelTypeRepository
    {
        ChannelType GetById(int id);
        IEnumerable<ChannelType> GetAll();
        void Add(Post.ChannelType channelType);
        void Update(ChannelType channelType);
        void Delete(int id);
    }
}
