import React, { useEffect, useState } from 'react'
import { Heart } from 'lucide-react'

interface HeartProps {
  id: number
  left: number
  animationDuration: number
  size: number
}

const FloatingHeart: React.FC<HeartProps> = ({ left, animationDuration, size }) => {
  return (
    <div
      className="floating-heart absolute"
      style={{
        left: `${left}%`,
        animationDuration: `${animationDuration}s`,
        fontSize: `${size}px`,
        animationDelay: `${Math.random() * 2}s`,
      }}
    >
      <Heart className="fill-current" />
    </div>
  )
}

const FloatingHearts: React.FC = () => {
  const [hearts, setHearts] = useState<HeartProps[]>([])

  useEffect(() => {
    const generateHearts = () => {
      const newHearts: HeartProps[] = []
      for (let i = 0; i < 15; i++) {
        newHearts.push({
          id: i,
          left: Math.random() * 100,
          animationDuration: 3 + Math.random() * 4,
          size: 12 + Math.random() * 8,
        })
      }
      setHearts(newHearts)
    }

    generateHearts()
  }, [])

  return (
    <div className="floating-hearts">
      {hearts.map((heart) => (
        <FloatingHeart key={heart.id} {...heart} />
      ))}
    </div>
  )
}

export default FloatingHearts
