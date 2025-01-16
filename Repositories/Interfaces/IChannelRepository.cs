using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IChannelRepository
    {
        Channel GetById(int id);
        IEnumerable<Channel> GetAll();
        void Add(Post.Channel channel);
        void Update(Channel channel);
        void Delete(int id);
    }
}
